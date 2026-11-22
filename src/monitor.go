package main

import (
	"bufio"
	"encoding/json"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type MonitorData struct {
	CPUPercent       float64  `json:"cpu_percent"`
	RAMPercent       float64  `json:"ram_percent"`
	RAMUsedMB        float64  `json:"ram_used_mb"`
	RAMTotalMB       float64  `json:"ram_total_mb"`
	DiskPercent      float64  `json:"disk_percent"`
	DiskUsedGiB      float64  `json:"disk_used_gib"`
	DiskTotalGiB     float64  `json:"disk_total_gib"`
	GPUAvailable     bool     `json:"gpu_available"`
	GPUPercent       *float64 `json:"gpu_percent"`
	GPUTempC         *float64 `json:"gpu_temp_c"`
	GPUVRAMPercent   *float64 `json:"gpu_vram_percent"`
	GPUVRAMUsedMB    *float64 `json:"gpu_vram_used_mb"`
	GPUVRAMTotalMB   *float64 `json:"gpu_vram_total_mb"`
	NetworkDownKiB   float64  `json:"network_down_kib_s"`
	NetworkUpKiB     float64  `json:"network_up_kib_s"`
	TemperatureC     *float64 `json:"temperature_c"`
}

func rounded(value float64) float64 {
	return math.Round(value*10) / 10
}

func cpuCounters() (uint64, uint64, bool) {
	file, err := os.Open("/proc/stat")
	if err != nil { return 0, 0, false }
	defer file.Close()

	scanner := bufio.NewScanner(file)
	if !scanner.Scan() { return 0, 0, false }
	fields := strings.Fields(scanner.Text())
	if len(fields) < 9 { return 0, 0, false }

	var total uint64
	values := make([]uint64, 8)
	for i := 0; i < 8; i++ {
		values[i], _ = strconv.ParseUint(fields[i+1], 10, 64)
		total += values[i]
	}
	return total, values[3] + values[4], true
}

func memoryUsage() (float64, float64, float64) {
	file, err := os.Open("/proc/meminfo")
	if err != nil { return 0, 0, 0 }
	defer file.Close()

	var total, available float64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		parts := strings.SplitN(scanner.Text(), ":", 2)
		if len(parts) != 2 { continue }
		value := strings.Fields(parts[1])
		if len(value) == 0 { continue }
		number, _ := strconv.ParseFloat(value[0], 64)
		if parts[0] == "MemTotal" { total = number }
		if parts[0] == "MemAvailable" { available = number }
	}

	if total <= 0 { return 0, 0, 0 }
	used := math.Max(0, total-available)
	return rounded(used/total*100), rounded(used/1024), rounded(total/1024)
}

func diskUsage() (float64, float64, float64) {
	output, err := exec.Command("df", "-B1", "--output=size,used,avail", "/").Output()
	if err != nil { return 0, 0, 0 }

	lines := strings.Split(string(output), "\n")
	if len(lines) < 2 { return 0, 0, 0 }
	fields := strings.Fields(lines[1])
	if len(fields) < 3 { return 0, 0, 0 }

	total, _ := strconv.ParseFloat(fields[0], 64)
	used, _ := strconv.ParseFloat(fields[1], 64)
	if total <= 0 { return 0, 0, 0 }
	return rounded(used/total*100), rounded(used/1073741824), rounded(total/1073741824)
}

func networkCounters() (uint64, uint64) {
	file, err := os.Open("/proc/net/dev")
	if err != nil { return 0, 0 }
	defer file.Close()

	var received, sent uint64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		parts := strings.SplitN(scanner.Text(), ":", 2)
		if len(parts) != 2 || strings.TrimSpace(parts[0]) == "lo" { continue }
		fields := strings.Fields(parts[1])
		if len(fields) < 9 { continue }
		r, _ := strconv.ParseUint(fields[0], 10, 64)
		s, _ := strconv.ParseUint(fields[8], 10, 64)
		received += r
		sent += s
	}
	return received, sent
}

func cpuTemperature() *float64 {
	dirs, err := filepath.Glob("/sys/class/hwmon/hwmon*")
	if err != nil { return nil }

	var highest float64
	found := false
	for _, dir := range dirs {
		chipData, _ := os.ReadFile(filepath.Join(dir, "name"))
		chip := strings.ToLower(strings.TrimSpace(string(chipData)))
		cpuChip := strings.Contains(chip, "coretemp") || strings.Contains(chip, "k10temp") || strings.Contains(chip, "zenpower")

		sensors, _ := filepath.Glob(filepath.Join(dir, "temp*_input"))
		for _, sensor := range sensors {
			stem := strings.TrimSuffix(sensor, "_input")
			labelData, _ := os.ReadFile(stem + "_label")
			label := strings.ToLower(strings.TrimSpace(string(labelData)))
			cpuLabel := false
			for _, word := range []string{"cpu", "package", "tctl", "tdie", "core"} {
				if strings.Contains(label, word) { cpuLabel = true }
			}
			if !cpuChip && !cpuLabel { continue }

			data, err := os.ReadFile(sensor)
			if err != nil { continue }
			raw, err := strconv.ParseFloat(strings.TrimSpace(string(data)), 64)
			if err != nil { continue }
			value := raw / 1000
			if value < -20 || value > 150 { continue }
			if !found || value > highest { highest, found = value, true }
		}
	}
	if !found { return nil }
	value := rounded(highest)
	return &value
}

func gpuData() (bool, *float64, *float64, *float64, *float64, *float64) {
	args := "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits"
	output, err := exec.Command("nvidia-smi", strings.Fields(args)...).Output()
	if err != nil { return false, nil, nil, nil, nil, nil }

	line := strings.SplitN(strings.TrimSpace(string(output)), "\n", 2)[0]
	values := strings.Split(line, ",")
	if len(values) < 4 { return false, nil, nil, nil, nil, nil }

	numbers := make([]*float64, 4)
	for i, value := range values {
		value = strings.TrimSpace(value)
		if strings.EqualFold(value, "N/A") { continue }
		n, err := strconv.ParseFloat(value, 64)
		if err == nil { numbers[i] = &n }
	}

	var vram *float64
	if numbers[2] != nil && numbers[3] != nil && *numbers[3] > 0 {
		value := rounded(*numbers[2] / *numbers[3] * 100)
		vram = &value
	}

	usage, temp := numbers[0], numbers[1]
	if usage != nil {
		value := rounded(math.Max(0, math.Min(100, *usage)))
		usage = &value
	}
	if temp != nil {
		value := rounded(*temp)
		temp = &value
	}

	var used, total *float64
	if numbers[2] != nil { value := rounded(*numbers[2]); used = &value }
	if numbers[3] != nil { value := rounded(*numbers[3]); total = &value }
	return true, usage, temp, vram, used, total
}

func runMonitor() {
	var oldTotal, oldIdle, oldReceived, oldSent uint64
	var oldNetTime time.Time
	hasCPU, hasNet := false, false
	encoder := json.NewEncoder(os.Stdout)

	for {
		start := time.Now()

		total, idle, ok := cpuCounters()
		cpu := 0.0
		if ok && hasCPU && total > oldTotal {
			delta := total - oldTotal
			idleDelta := idle - oldIdle
			cpu = rounded((1 - float64(idleDelta)/float64(delta)) * 100)
		}
		if ok { oldTotal, oldIdle, hasCPU = total, idle, true }

		ram, ramUsed, ramTotal := memoryUsage()
		disk, diskUsed, diskTotal := diskUsage()
		received, sent := networkCounters()

		down, up := 0.0, 0.0
		now := time.Now()
		if hasNet {
			elapsed := now.Sub(oldNetTime).Seconds()
			if elapsed < 0.001 { elapsed = 0.001 }
			if received >= oldReceived { down = rounded(float64(received-oldReceived)/1024/elapsed) }
			if sent >= oldSent { up = rounded(float64(sent-oldSent)/1024/elapsed) }
		}
		oldReceived, oldSent, oldNetTime, hasNet = received, sent, now, true

		gpuAvailable, gpu, gpuTemp, vram, vramUsed, vramTotal := gpuData()
		data := MonitorData{
			CPUPercent: cpu, RAMPercent: ram, RAMUsedMB: ramUsed, RAMTotalMB: ramTotal,
			DiskPercent: disk, DiskUsedGiB: diskUsed, DiskTotalGiB: diskTotal,
			GPUAvailable: gpuAvailable, GPUPercent: gpu, GPUTempC: gpuTemp,
			GPUVRAMPercent: vram, GPUVRAMUsedMB: vramUsed, GPUVRAMTotalMB: vramTotal,
			NetworkDownKiB: down, NetworkUpKiB: up, TemperatureC: cpuTemperature(),
		}
		if err := encoder.Encode(data); err != nil { return }

		if delay := time.Second - time.Since(start); delay > 0 { time.Sleep(delay) }
	}
}
