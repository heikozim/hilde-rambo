// Command goconfig writes what Go's standard library makes of the inputs
// rambo's configuration reader is tested with, so that the test compares
// against Go and not against a reading of its source.
//
// Each input line is "d TEXT" (time.ParseDuration, then Duration.String)
// or "i TEXT" (strconv.Atoi).  Each output line is the kind, a tab, the
// input, a tab and the answer: the value, or "none" when Go refuses it;
// for a duration a tab and its String follow.  The input (empty) stands
// for the empty text, and a micro sign in a String is written u.
//
//	go run . < inputs.txt > expected.txt
package main

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

func main() {
	in := bufio.NewScanner(os.Stdin)
	out := bufio.NewWriter(os.Stdout)
	for in.Scan() {
		line := in.Text()
		if len(line) < 2 || line[1] != ' ' {
			fmt.Fprintf(os.Stderr, "goconfig: bad line %q\n", line)
			os.Exit(2)
		}
		kind, text := line[:1], line[2:]
		if text == "(empty)" {
			text = ""
		}
		switch kind {
		case "d":
			d, err := time.ParseDuration(text)
			if err != nil {
				fmt.Fprintf(out, "d\t%s\tnone\n", text)
			} else {
				fmt.Fprintf(out, "d\t%s\t%d\t%s\n", text, int64(d), strings.ReplaceAll(d.String(), "\u00b5", "u"))
			}
		case "i":
			n, err := strconv.Atoi(text)
			if err != nil {
				fmt.Fprintf(out, "i\t%s\tnone\n", text)
			} else {
				fmt.Fprintf(out, "i\t%s\t%d\n", text, n)
			}
		default:
			fmt.Fprintf(os.Stderr, "goconfig: unknown kind %q\n", kind)
			os.Exit(2)
		}
	}
	if err := in.Err(); err != nil {
		fmt.Fprintln(os.Stderr, "goconfig:", err)
		os.Exit(2)
	}
	if err := out.Flush(); err != nil {
		fmt.Fprintln(os.Stderr, "goconfig:", err)
		os.Exit(2)
	}
}
