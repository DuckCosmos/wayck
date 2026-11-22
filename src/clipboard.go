package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func clipboardPrefix() string {
	return fmt.Sprintf("wayck_clip_%d_", os.Geteuid())
}

func validClipboardID(id string) bool {
	if id == "" { return false }
	for _, r := range id {
		if r < '0' || r > '9' { return false }
	}
	return true
}

func decodeImage(id string) string {
	path := filepath.Join(os.TempDir(), clipboardPrefix()+id+".png")
	if _, err := os.Stat(path); err == nil { return path }

	tmp := filepath.Join(os.TempDir(), clipboardPrefix()+id+".tmp")
	out, err := os.Create(tmp)
	if err != nil { return "" }

	cmd := exec.Command("cliphist", "decode", id)
	cmd.Stdout = out
	err = cmd.Run()
	out.Close()
	if err != nil {
		os.Remove(tmp)
		return ""
	}

	if os.Rename(tmp, path) != nil {
		os.Remove(tmp)
		return ""
	}
	os.Chmod(path, 0600)
	return path
}

func listClipboard(term string) []ClipboardItem {
	items := []ClipboardItem{}
	cmd := exec.Command("cliphist", "list")
	output, err := cmd.Output()
	if err != nil { return items }

	query := strings.ToLower(term)
	for _, line := range strings.Split(string(output), "\n") {
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) != 2 || !validClipboardID(parts[0]) { continue }

		id, content := parts[0], parts[1]
		if query != "" && !strings.Contains(strings.ToLower(content), query) { continue }

		isImage := strings.HasPrefix(content, "[[ binary data") && strings.Contains(strings.ToLower(content), "png")
		path := ""
		if isImage {
			path = decodeImage(id)
			if path == "" { continue }
		}
		content = strings.ReplaceAll(content, "\n", " ")
		items = append(items, ClipboardItem{ID: id, Content: content, IsImage: isImage, Path: path})
		if len(items) == 50 { break }
	}
	return items
}

func copyClipboard(id string) {
	if !validClipboardID(id) { return }

	source := exec.Command("cliphist", "decode", id)
	pipe, err := source.StdoutPipe()
	if err != nil { return }

	target := exec.Command("wl-copy")
	target.Stdin = pipe
	if target.Start() != nil { return }
	if source.Start() != nil { target.Process.Kill(); return }

	source.Wait()
	target.Wait()
}

func deleteClipboard(id string) {
	if !validClipboardID(id) { return }
	cmd := exec.Command("cliphist", "delete")
	cmd.Stdin = strings.NewReader(id + "\n")
	cmd.Run()
}

func clearClipboard() {
	exec.Command("wl-copy", "--clear").Run()
	exec.Command("cliphist", "wipe").Run()

	files, _ := filepath.Glob(filepath.Join(os.TempDir(), clipboardPrefix()+"*.png"))
	for _, file := range files { os.Remove(file) }
}
