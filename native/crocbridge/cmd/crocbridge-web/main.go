package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"dev.sarrietav/crocbridge/webbridge"
)

func main() {
	address := flag.String("addr", envOr("CROC_WEB_ADDR", ":8080"), "HTTP listen address")
	webRoot := flag.String("web-root", envOr("CROC_WEB_ROOT", ""), "Flutter web build directory")
	storage := flag.String("storage", envOr("CROC_WEB_STORAGE", ""), "temporary transfer directory")
	flag.Parse()

	server, err := webbridge.New(*storage, os.Getenv("CROC_WEB_ORIGIN"))
	if err != nil {
		log.Fatal(err)
	}
	if *webRoot != "" {
		absolute, err := filepath.Abs(*webRoot)
		if err != nil {
			log.Fatal(err)
		}
		*webRoot = absolute
	}
	log.Printf("Croc web bridge listening on %s", *address)
	log.Fatal(http.ListenAndServe(webbridge.ParseAddress(*address), server.Handler(*webRoot)))
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
