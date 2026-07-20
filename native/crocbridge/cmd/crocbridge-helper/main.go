package main

import (
	"fmt"
	"os"

	"dev.sarrietav/crocbridge/desktopipc"
	"github.com/schollz/logger"
)

func main() {
	logger.SetOutput(os.Stderr)
	logger.SetLevel("error")
	if err := desktopipc.Serve(os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
