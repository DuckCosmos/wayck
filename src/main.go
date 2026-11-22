package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
)

type App struct {
	Nome      string `json:"nome"`
	IconePath string `json:"icone_path"`
	Exec      string `json:"exec"`
}

type ClipboardItem struct {
	ID      string `json:"id"`
	Content string `json:"content"`
	IsImage bool   `json:"is_image"`
	Path    string `json:"path"`
}

type VersionInfo struct {
	Local     string `json:"local"`
	Remote    string `json:"remote"`
	Available bool   `json:"available"`
}

func printJSON(value any) {
	if err := json.NewEncoder(os.Stdout).Encode(value); err != nil {
		fmt.Fprintln(os.Stderr, err)
	}
}

func run() error {
	args := os.Args[1:]
	if len(args) == 0 {
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			printJSON(filterApps(scanner.Text()))
		}
		return scanner.Err()
	}

	command := args[0]
	rest := args[1:]

	switch command {
	case "--monitor":
		runMonitor()
	case "--filter":
		query := ""
		if len(rest) > 0 {
			query = rest[0]
		}
		printJSON(filterApps(query))
	case "--exec":
		if len(rest) >= 2 {
			registerUsage(rest[0])
			runApp(rest[1], rest[0])
		}
	case "--clipboard-list":
		query := ""
		if len(rest) > 0 {
			query = rest[0]
		}
		printJSON(listClipboard(query))
	case "--clipboard-copy":
		if len(rest) > 0 {
			copyClipboard(rest[0])
		}
	case "--clipboard-delete":
		if len(rest) > 0 {
			deleteClipboard(rest[0])
		}
	case "--clipboard-clear":
		clearClipboard()
	case "--check_version":
		info, err := checkVersion()
		if err != nil {
			return err
		}
		fmt.Println(info.Available)
	case "--version_info":
		info, err := checkVersion()
		if err != nil {
			return err
		}
		printJSON(info)
	}

	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "Wayck backend:", err)
		os.Exit(1)
	}
}
