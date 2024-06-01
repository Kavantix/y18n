package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/Kavantix/y18n/internal/tree"
	"github.com/rsc/getopt"
)

var (
	help = flag.Bool("help", false, "Shows this help message.")
	path = flag.String("file", "", `(required) The path to the strings file e.g. './strings.yaml'`)
)

func eprintln(line string) {
	fmt.Fprintln(os.Stderr, line)
}

func eprintf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format, args...)
}

func failWithUsage() {
	flag.Usage()
	os.Exit(1)
}

func setupArgs() {
	getopt.Alias("h", "help")
	getopt.Alias("f", "file")
	getopt.Parse()

	if *help {
		failWithUsage()
	}
}

func main() {
	setupArgs()

	if *path == "" {
		eprintln("ERROR: file is required")
		failWithUsage()
	}

	file, err := os.Open(*path)
	if err != nil {
		eprintf("ERROR: failed to open file '%s': %s", *path, err)
		os.Exit(1)
	}

	tree, err := tree.ParseYaml(file)
	if err != nil {
		eprintf("ERROR: failed to parse file '%s': %s", *path, err)
		os.Exit(1)
	}
	fmt.Printf("%+v", tree)
}
