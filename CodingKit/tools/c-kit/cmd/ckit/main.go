package main

import (
	"fmt"
	"os"

	"c-kit/internal/ckit"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: ckit <init|demo|snippet|lint|contract|doctor|bench|verify> [args]")
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "init":
		err = ckit.RunInit(os.Args[2:])
	case "demo":
		err = ckit.RunDemo(os.Args[2:])
	case "snippet":
		err = ckit.RunSnippet(os.Args[2:])
	case "lint", "check":
		err = ckit.RunLint(os.Args[2:])
	case "contract":
		err = ckit.RunContract(os.Args[2:])
	case "doctor":
		err = ckit.RunDoctor(os.Args[2:])
	case "bench":
		err = ckit.RunBench(os.Args[2:])
	case "verify":
		err = ckit.RunVerify(os.Args[2:])
	default:
		err = fmt.Errorf("unknown command %q", os.Args[1])
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
