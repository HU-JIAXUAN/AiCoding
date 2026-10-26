// Command motor-engineering performs bounded, read-only motor-control analysis.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"reflect"
)

type paths []string

func (p *paths) String() string     { return fmt.Sprint([]string(*p)) }
func (p *paths) Set(s string) error { *p = append(*p, s); return nil }

// Exit codes: 0 computed/inspected, 2 insufficient evidence, 3 violated constraint,
// 4 invalid input or I/O. Source inspection never certifies running hardware.
func run(args []string, out io.Writer) int {
	if len(args) == 0 {
		return emitError(out, "INVALID_COMMAND", "use inspect --project DIR --file RELPATH, or analyze --input FILE")
	}
	f := flag.NewFlagSet(args[0], flag.ContinueOnError)
	f.SetOutput(io.Discard)
	var result any
	code := 0
	switch args[0] {
	case "schema":
		kind := f.String("kind", "timing-input", "timing-input, timing-report or inspection")
		if err := f.Parse(args[1:]); err != nil || f.NArg() != 0 {
			return emitError(out, "INVALID_INPUT", "invalid schema arguments")
		}
		var typ reflect.Type
		switch *kind {
		case "timing-input":
			typ = reflect.TypeOf(TimingInput{})
		case "timing-report":
			typ = reflect.TypeOf(TimingReport{})
		case "inspection":
			typ = reflect.TypeOf(Inspection{})
		default:
			return emitError(out, "INVALID_INPUT", "unsupported schema kind")
		}
		schema := schemaFor(typ)
		schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
		schema["title"] = *kind
		result = schema
	case "inspect":
		project := f.String("project", "", "explicit project root")
		var files paths
		f.Var(&files, "file", "project-relative source/config; repeat to bound scope")
		if err := f.Parse(args[1:]); err != nil || f.NArg() != 0 || *project == "" || len(files) == 0 {
			return emitError(out, "INVALID_INPUT", "inspect requires --project and at least one --file; no recursive scan")
		}
		r, err := inspect(*project, files)
		if err != nil {
			return emitError(out, "INVALID_INPUT", err.Error())
		}
		result = r
	case "analyze":
		input := f.String("input", "", "timing input JSON")
		if err := f.Parse(args[1:]); err != nil || f.NArg() != 0 || *input == "" {
			return emitError(out, "INVALID_INPUT", "analyze requires --input")
		}
		data, err := os.Open(*input)
		if err != nil {
			return emitError(out, "IO_ERROR", err.Error())
		}
		defer data.Close()
		content, err := io.ReadAll(io.LimitReader(data, (2<<20)+1))
		if err != nil || len(content) > 2<<20 {
			return emitError(out, "INVALID_INPUT", "cannot read input <=2MiB")
		}
		var shape any
		if err = rejectDuplicateKeys(content); err != nil {
			return emitError(out, "INVALID_INPUT", err.Error())
		}
		if err = json.Unmarshal(content, &shape); err != nil {
			return emitError(out, "INVALID_INPUT", err.Error())
		}
		if err = requiredFields(shape, reflect.TypeOf(TimingInput{}), "input"); err != nil {
			return emitError(out, "INVALID_INPUT", err.Error())
		}
		var request TimingInput
		decoder := json.NewDecoder(bytes.NewReader(content))
		decoder.DisallowUnknownFields()
		if err = decoder.Decode(&request); err != nil {
			return emitError(out, "INVALID_INPUT", err.Error())
		}
		var extra any
		if err = decoder.Decode(&extra); err != io.EOF {
			return emitError(out, "INVALID_INPUT", "trailing JSON or oversized input")
		}
		r := analyze(request)
		result = r
		switch r.Status {
		case "INVALID":
			code = 4
		case "INSUFFICIENT_EVIDENCE":
			code = 2
		case "CONSTRAINT_VIOLATION":
			code = 3
		}
	default:
		return emitError(out, "INVALID_COMMAND", "supported commands: inspect, analyze")
	}
	encoder := json.NewEncoder(out)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(result); err != nil {
		return emitError(out, "NUMERIC_OUTPUT", err.Error())
	}
	return code
}

func emitError(out io.Writer, code, message string) int {
	_ = json.NewEncoder(out).Encode(map[string]string{"status": "INVALID", "code": code, "message": message})
	return 4
}

func main() { os.Exit(run(os.Args[1:], os.Stdout)) }
