package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"
)

const versionURL = "https://raw.githubusercontent.com/DuckCosmos/wayck/main/version.txt"

func localVersion() string {
	var paths []string

	exe, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(exe)
		paths = append(paths, filepath.Join(dir, "version.txt"))

		for i := 0; i < 3; i++ {
			dir = filepath.Dir(dir)
		}
		paths = append(paths, filepath.Join(dir, "version.txt"))
	}

	if dir, err := os.Getwd(); err == nil {
		paths = append(paths, filepath.Join(dir, "version.txt"))
	}

	for _, path := range paths {
		data, err := os.ReadFile(path)
		if err == nil {
			return strings.TrimSpace(string(data))
		}
	}

	return ""
}

func remoteVersion() (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, versionURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Wayck-Updater/1.0")

	client := http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("servidor respondeu %s", resp.Status)
	}

	data, err := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if err != nil {
		return "", err
	}

	text := string(data)
	if !utf8.ValidString(text) {
		return "", fmt.Errorf("versão remota não é UTF-8 válido")
	}

	runes := []rune(text)
	if len(runes) > 256 {
		text = string(runes[:256])
	}

	return strings.TrimSpace(text), nil
}

func checkVersion() (VersionInfo, error) {
	local := localVersion()
	remote, err := remoteVersion()
	if err != nil {
		return VersionInfo{}, err
	}

	return VersionInfo{
		Local: local,
		Remote: remote,
		Available: local != "" && remote != "" && remote != local,
	}, nil
}
