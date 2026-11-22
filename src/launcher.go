package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"syscall"
)

func applicationDirs() []string {
	home, _ := os.UserHomeDir()
	return []string{
		"/usr/share/applications",
		"/usr/local/share/applications",
		"/var/lib/flatpak/exports/share/applications",
		filepath.Join(home, ".local/share/applications"),
		filepath.Join(home, ".local/share/flatpak/exports/share/applications"),
	}
}

func iconPath(icon string) string {
	if icon == "" { return "" }

	home, _ := os.UserHomeDir()
	icon = strings.ReplaceAll(icon, "~", home)

	if filepath.IsAbs(icon) {
		if fileExists(icon) { return icon }
		return ""
	}
	if strings.ContainsAny(icon, "/\\") || icon == "." || icon == ".." { return "" }

	roots := []string{
		"/usr/share/icons/Papirus/48x48/apps",
		"/usr/share/icons/Papirus-Dark/48x48/apps",
		"/usr/share/icons/hicolor/scalable/apps",
		"/usr/share/icons/hicolor/256x256/apps",
		"/usr/share/icons/hicolor/128x128/apps",
		"/usr/share/icons/hicolor/48x48/apps",
		"/usr/share/pixmaps",
		filepath.Join(home, ".local/share/icons/hicolor/scalable/apps"),
		filepath.Join(home, ".local/share/icons/hicolor/256x256/apps"),
		filepath.Join(home, ".local/share/icons/hicolor/128x128/apps"),
		filepath.Join(home, ".local/share/icons/hicolor/48x48/apps"),
		filepath.Join(home, ".local/share/icons/Papirus/48x48/apps"),
		"/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps",
		"/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps",
		"/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps",
		filepath.Join(home, ".local/share/flatpak/exports/share/icons/hicolor/128x128/apps"),
		filepath.Join(home, ".local/share/flatpak/exports/share/icons/hicolor/64x64/apps"),
		filepath.Join(home, ".local/share/flatpak/exports/share/icons/hicolor/scalable/apps"),
	}

	for _, root := range roots {
		for _, ext := range []string{"svg", "png", "xpm"} {
			path := filepath.Join(root, icon+"."+ext)
			if fileExists(path) { return path }
		}
	}

	fallback := "/usr/share/icons/Papirus/48x48/apps/terminal.svg"
	if fileExists(fallback) { return fallback }
	return ""
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func readDesktop(path string) *App {
	data, err := os.ReadFile(path)
	if err != nil { return nil }

	inEntry := false
	name, portuguese, icon, command := "", "", "", ""

	for _, raw := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(raw)

		if strings.HasPrefix(line, "[") {
			inEntry = line == "[Desktop Entry]"
			continue
		}
		if !inEntry || line == "" || strings.HasPrefix(line, "#") { continue }

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 { continue }

		key, value := parts[0], parts[1]
		if (key == "NoDisplay" || key == "Hidden") && strings.EqualFold(value, "true") {
			return nil
		}

		switch key {
		case "Name[pt_BR]": portuguese = value
		case "Name": name = value
		case "Icon": icon = value
		case "Exec": command = value
		}
	}

	if portuguese != "" { name = portuguese }
	if name == "" || command == "" { return nil }

	return &App{Nome: name, IconePath: iconPath(icon), Exec: command}
}

func loadApps() []App {
	apps := []App{}
	seen := map[string]bool{}

	for _, dir := range applicationDirs() {
		paths, err := filepath.Glob(filepath.Join(dir, "*.desktop"))
		if err != nil { continue }
		sort.Strings(paths)

		for _, path := range paths {
			app := readDesktop(path)
			if app == nil || seen[app.Nome] { continue }
			seen[app.Nome] = true
			apps = append(apps, *app)
		}
	}

	sort.Slice(apps, func(i, j int) bool {
		return strings.ToLower(apps[i].Nome) < strings.ToLower(apps[j].Nome)
	})
	return apps
}

func filterApps(text string) []App {
	query := strings.ToLower(text)
	usage := readUsage()
	apps := []App{}

	for _, app := range loadApps() {
		if strings.Contains(strings.ToLower(app.Nome), query) {
			apps = append(apps, app)
		}
	}

	sort.SliceStable(apps, func(i, j int) bool {
		return usage[apps[i].Nome] > usage[apps[j].Nome]
	})
	if len(apps) > 15 { apps = apps[:15] }

	if result := calculate(text); result != "" {
		apps = append([]App{{Nome: strings.TrimSpace(text) + " = " + result, IconePath: iconPath("accessories-calculator"), Exec: "@copy:" + result}}, apps...)
	} else if len(apps) == 0 && strings.TrimSpace(text) != "" {
		apps = append(apps, App{Nome: text, IconePath: iconPath("kitty"), Exec: "@term:" + text})
	}

	return apps
}

func splitCommand(input string) []string {
	parts := []string{}
	var current strings.Builder
	quote := rune(0)
	escape := false

	for _, char := range input {
		if escape {
			current.WriteRune(char)
			escape = false
			continue
		}
		if quote != '\'' && char == '\\' {
			escape = true
			continue
		}
		if quote == 0 && (char == '\'' || char == '"') {
			quote = char
			continue
		}
		if quote != 0 && char == quote {
			quote = 0
			continue
		}
		if quote == 0 && (char == ' ' || char == '\t' || char == '\n') {
			if current.Len() > 0 {
				parts = append(parts, current.String())
				current.Reset()
			}
			continue
		}
		current.WriteRune(char)
	}

	if escape || quote != 0 { return nil }
	if current.Len() > 0 { parts = append(parts, current.String()) }
	return parts
}

func findProgram(name string) string {
	if strings.Contains(name, "/") {
		if info, err := os.Stat(name); err == nil && info.Mode().IsRegular() && info.Mode()&0111 != 0 {
			return name
		}
		return ""
	}
	for _, dir := range filepath.SplitList(os.Getenv("PATH")) {
		path := filepath.Join(dir, name)
		if info, err := os.Stat(path); err == nil && info.Mode().IsRegular() && info.Mode()&0111 != 0 {
			return path
		}
	}
	return ""
}

func terminalCommand() []string {
	if configured := os.Getenv("TERMINAL"); configured != "" {
		parts := splitCommand(configured)
		if len(parts) > 0 && findProgram(parts[0]) != "" { return parts }
	}
	for _, name := range []string{"kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal", "kgx", "xterm"} {
		if path := findProgram(name); path != "" { return []string{path} }
	}
	return nil
}

func startDetached(args []string) {
	if len(args) == 0 { return }

	cmd := exec.Command(args[0], args[1:]...)
	devNull, err := os.OpenFile(os.DevNull, os.O_RDWR, 0)
	if err != nil { return }
	defer devNull.Close()

	cmd.Stdin = devNull
	cmd.Stdout = devNull
	cmd.Stderr = devNull
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if cmd.Start() == nil {
		go cmd.Wait()
	}
}

func openTerminal(command string) {
	term := terminalCommand()
	if len(term) == 0 { return }

	shell := os.Getenv("SHELL")
	if shell == "" { shell = "/bin/sh" }
	quotedShell := "'" + strings.ReplaceAll(shell, "'", "'\\''") + "'"
	shellCommand := command + "; exec " + quotedShell
	name := filepath.Base(term[0])

	switch name {
	case "gnome-terminal", "kgx":
		term = append(term, "--", "sh", "-lc", shellCommand)
	case "wezterm":
		term = append(term, "start", "--", "sh", "-lc", shellCommand)
	default:
		term = append(term, "-e", "sh", "-lc", shellCommand)
	}
	startDetached(term)
}

func runApp(command, appName string) {
	if strings.HasPrefix(command, "@term:") {
		openTerminal(strings.TrimPrefix(command, "@term:"))
		return
	}

	if strings.HasPrefix(command, "@copy:") {
		cmd := exec.Command("wl-copy")
		cmd.Stdin = strings.NewReader(strings.TrimPrefix(command, "@copy:"))
		cmd.Run()
		return
	}

	parts := splitCommand(command)
	if len(parts) == 0 { return }

	fieldCodes := regexp.MustCompile("%(?:[fFuUdDnNickvm])")
	clean := []string{}

	for _, part := range parts {
		switch part {
		case "%f", "%F", "%u", "%U", "%i", "%d", "%D", "%n", "%N", "%v", "%m":
			continue
		}
		part = strings.ReplaceAll(part, "%c", appName)
		part = fieldCodes.ReplaceAllString(part, "")
		if part != "" { clean = append(clean, part) }
	}

	if len(clean) == 0 || findProgram(clean[0]) == "" { return }
	startDetached(clean)
}
