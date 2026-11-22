package main

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"unicode"
)

func usagePath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "wayck_uso.txt")
}

func readUsage() map[string]int {
	result := map[string]int{}
	data, err := os.ReadFile(usagePath())
	if err != nil {
		return result
	}

	for _, line := range strings.Split(string(data), "\n") {
		i := strings.LastIndex(line, "\t")
		if i < 1 {
			continue
		}
		count, err := strconv.Atoi(line[i+1:])
		if err == nil {
			result[line[:i]] = count
		}
	}
	return result
}

func registerUsage(name string) {
	if name == "" || len(name) > 512 {
		return
	}

	usage := readUsage()
	usage[name]++
	if usage[name] > 2147483647 {
		usage[name] = 2147483647
	}

	keys := make([]string, 0, len(usage))
	for key := range usage {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	var data strings.Builder
	for _, key := range keys {
		fmt.Fprintf(&data, "%s\t%d\n", key, usage[key])
	}

	path := usagePath()
	os.MkdirAll(filepath.Dir(path), 0755)
	tmp := path + ".tmp"
	if os.WriteFile(tmp, []byte(data.String()), 0600) == nil {
		os.Rename(tmp, path)
	}
}

func calculate(input string) string {
	expr := strings.TrimSpace(input)
	expr = strings.NewReplacer("×", "*", "÷", "/", "x", "*", "X", "*", ",", ".").Replace(expr)
	if len(expr) == 0 || len(expr) > 120 {
		return ""
	}

	hasNumber := false
	for _, r := range expr {
		if r >= '0' && r <= '9' {
			hasNumber = true
			break
		}
	}
	if !hasNumber {
		return ""
	}

	p := expression{input: expr}
	value, err := p.addSub()
	if err != nil {
		return ""
	}

	p.skip()
	if p.pos != len(p.input) || math.IsInf(value, 0) || math.IsNaN(value) {
		return ""
	}

	if value == math.Trunc(value) && value >= math.MinInt64 && value < math.MaxInt64 {
		return strconv.FormatInt(int64(value), 10)
	}

	result := strconv.FormatFloat(value, 'f', 12, 64)
	result = strings.TrimRight(strings.TrimRight(result, "0"), ".")
	if strings.Contains(input, ",") {
		result = strings.ReplaceAll(result, ".", ",")
	}
	return result
}

type expression struct {
	input string
	pos   int
}

func (p *expression) skip() {
	for p.pos < len(p.input) && unicode.IsSpace(rune(p.input[p.pos])) {
		p.pos++
	}
}

func (p *expression) take(c byte) bool {
	p.skip()
	if p.pos < len(p.input) && p.input[p.pos] == c {
		p.pos++
		return true
	}
	return false
}

func (p *expression) addSub() (float64, error) {
	value, err := p.mulDiv()
	if err != nil { return 0, err }
	for {
		if p.take('+') {
			n, e := p.mulDiv(); if e != nil { return 0, e }; value += n
		} else if p.take('-') {
			n, e := p.mulDiv(); if e != nil { return 0, e }; value -= n
		} else { return value, nil }
	}
}

func (p *expression) mulDiv() (float64, error) {
	value, err := p.power()
	if err != nil { return 0, err }
	for {
		if p.take('*') {
			n, e := p.power(); if e != nil { return 0, e }; value *= n
		} else if p.take('/') {
			n, e := p.power(); if e != nil { return 0, e }; value /= n
		} else { return value, nil }
	}
}

func (p *expression) power() (float64, error) {
	value, err := p.unary()
	if err != nil { return 0, err }
	if p.take('^') {
		n, e := p.power(); if e != nil { return 0, e }
		return math.Pow(value, n), nil
	}
	return value, nil
}

func (p *expression) unary() (float64, error) {
	if p.take('+') { return p.unary() }
	if p.take('-') { n, err := p.unary(); return -n, err }
	return p.atom()
}

func (p *expression) atom() (float64, error) {
	p.skip()
	if p.take('(') {
		value, err := p.addSub()
		if err != nil || !p.take(')') { return 0, fmt.Errorf("parênteses inválidos") }
		return value, nil
	}

	start := p.pos
	for p.pos < len(p.input) && (p.input[p.pos] >= '0' && p.input[p.pos] <= '9' || p.input[p.pos] == '.') {
		p.pos++
	}
	if start != p.pos {
		return strconv.ParseFloat(p.input[start:p.pos], 64)
	}

	start = p.pos
	for p.pos < len(p.input) && unicode.IsLetter(rune(p.input[p.pos])) { p.pos++ }
	if start == p.pos { return 0, fmt.Errorf("expressão inválida") }

	name := strings.ToLower(p.input[start:p.pos])
	if p.take('(') {
		arg, err := p.addSub()
		if err != nil || !p.take(')') { return 0, fmt.Errorf("função inválida") }
		switch name {
		case "abs": return math.Abs(arg), nil
		case "acos": return math.Acos(arg), nil
		case "asin": return math.Asin(arg), nil
		case "atan": return math.Atan(arg), nil
		case "ceil": return math.Ceil(arg), nil
		case "cos": return math.Cos(arg), nil
		case "cosh": return math.Cosh(arg), nil
		case "exp": return math.Exp(arg), nil
		case "floor": return math.Floor(arg), nil
		case "ln", "log": return math.Log(arg), nil
		case "log10": return math.Log10(arg), nil
		case "log2": return math.Log2(arg), nil
		case "round": return math.Round(arg), nil
		case "sin": return math.Sin(arg), nil
		case "sinh": return math.Sinh(arg), nil
		case "sqrt": return math.Sqrt(arg), nil
		case "tan": return math.Tan(arg), nil
		case "tanh": return math.Tanh(arg), nil
		}
		return 0, fmt.Errorf("função desconhecida")
	}

	switch name {
	case "pi": return math.Pi, nil
	case "e": return math.E, nil
	case "tau": return math.Pi * 2, nil
	}
	return 0, fmt.Errorf("constante desconhecida")
}
