import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from visio_mcp.protocol import PROTOCOL_VERSION


async def protocol_scenario():
    environment = os.environ.copy()
    environment["PYTHONPATH"] = str((Path.cwd() / "src").resolve())
    parameters = StdioServerParameters(
        command=sys.executable,
        args=["-m", "visio_mcp", "--renderer", "mock", "server"],
        cwd=str(Path.cwd()),
        env=environment,
    )
    async with stdio_client(parameters) as (read, write):
        async with ClientSession(read, write) as session:
            initialized = await session.initialize()
            tools = await session.list_tools()
            resources = await session.list_resources()
            prompts = await session.list_prompts()
            if initialized.capabilities.logging is not None:
                await session.set_logging_level("info")
            invalid = await session.call_tool("diagram_validate", {"diagram": {}})
            await session.send_ping()
            return initialized, tools, resources, prompts, invalid


def test_official_client_lifecycle_and_annotations():
    initialized, tools, resources, prompts, invalid = asyncio.run(protocol_scenario())
    assert initialized.protocolVersion == PROTOCOL_VERSION
    assert len(tools.tools) == 12
    assert all(tool.annotations is not None for tool in tools.tools)
    assert {
        str(resource.uri)
        for resource in resources.resources
    } == {
        "visio://schemas/diagram",
        "visio://schemas/renderer-effective-fields",
        "visio://schemas/style-profile",
        "visio://styles/profiles",
    }
    assert len(prompts.prompts) == 0
    assert initialized.capabilities.logging is None
    assert invalid.isError is True


def test_invalid_json_does_not_break_following_ping():
    process = subprocess.Popen(
        [sys.executable, "-m", "visio_mcp", "--renderer", "mock", "server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    payload = (
        "{invalid-json}\n"
        + json.dumps(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": PROTOCOL_VERSION,
                    "capabilities": {},
                    "clientInfo": {"name": "raw-probe", "version": "1"},
                },
            }
        )
        + "\n"
    )
    stdout, _ = process.communicate(payload, timeout=20)
    assert process.returncode == 0
    assert any(json.loads(line).get("id") == 1 for line in stdout.splitlines() if line.startswith("{"))


def _run_doctor_in_fresh_process(script):
    component = Path(__file__).resolve().parents[1]
    environment = os.environ.copy()
    environment["PYTHONPATH"] = str(component / "src")
    environment["VISIO_MCP_ROOT"] = str(component)
    environment["VISIO_MCP_OUTPUT_ROOTS"] = "dist;test-results;generated"
    return subprocess.run(
        [sys.executable, "-B", "-c", script],
        cwd=component,
        env=environment,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=20,
    )


def test_doctor_does_not_load_server_protocol_or_mcp_modules():
    process = _run_doctor_in_fresh_process(
        r'''
import sys

class NoServerProtocol:
    def find_spec(self, fullname, path=None, target=None):
        if fullname == "visio_mcp.protocol":
            raise AssertionError("doctor must not load the server protocol")
        return None

sys.meta_path.insert(0, NoServerProtocol())
sys.argv = ["visio-mcp", "--renderer", "mock", "doctor", "--json"]
from visio_mcp.__main__ import main
main()
assert not any(name == "mcp" or name.startswith("mcp.") for name in sys.modules)
'''
    )
    assert process.returncode == 0, process.stderr
    result = json.loads(process.stdout)
    component = Path(__file__).resolve().parents[1]
    registry_path = component / "styles" / "style-profiles.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    assert set(result) == {"service", "platform", "renderer", "styleProfiles", "allowedOutputRoots"}
    assert result["service"] == "visio-mcp"
    assert isinstance(result["platform"], str) and result["platform"]
    assert result["renderer"] == {"available": True, "renderer": "mock", "visibleEditing": False}
    assert result["styleProfiles"] == {
        "available": True,
        "path": str(registry_path),
        "default": registry["defaultProfile"],
        "profiles": sorted(registry["profiles"]),
    }
    assert result["allowedOutputRoots"] == [
        str(component / name) for name in ("dist", "test-results", "generated")
    ]


def test_doctor_fails_when_required_mcp_package_is_missing():
    process = _run_doctor_in_fresh_process(
        r'''
import importlib.util
import sys

find_spec = importlib.util.find_spec

def missing_mcp(name, package=None):
    return None if name == "mcp" else find_spec(name, package)

importlib.util.find_spec = missing_mcp
sys.argv = ["visio-mcp", "--renderer", "mock", "doctor", "--json"]
from visio_mcp.__main__ import main
main()
'''
    )
    assert process.returncode != 0
    assert "ModuleNotFoundError: No module named 'mcp'" in process.stderr
    assert not process.stdout.strip()
