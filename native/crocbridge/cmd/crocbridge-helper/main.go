package main

import (
	"fmt"
	"os"

	"dev.sarrietav/crocbridge/desktopipc"
)

func main() {
	if err := desktopipc.Serve(os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
