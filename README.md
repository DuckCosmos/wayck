# Wayck

**A modern, modular and customizable desktop shell for Linux.**

Wayck is a Linux desktop shell built with **Rust, Quickshell and QML**, designed to provide a cohesive desktop experience through a modular, efficient and maintainable architecture.

It combines desktop controls, system monitoring and productivity tools in a unified interface.

---

## Preview

| **DESKTOP BAR** | **CLIPBOARD** | **APPLICATION LAUNCHER** |
|:---:|:---:|:---:|
| System monitoring and desktop controls | Clipboard history and management | Quick application access |
| ![Wayck Bar](docs/bar.png) | ![Wayck Clipboard](docs/clipboard.png) | ![Wayck Launcher](docs/launcher.png) |

---

## Features

### Desktop Bar

A modular desktop bar combining system information, workspace management and desktop controls.

- **Workspaces:** workspace management and navigation.
- **Media:** media player information and playback controls.
- **Audio:** audio controls and volume information.
- **System Tray:** access to tray applications.
- **Clock:** desktop clock.
- **System Monitoring:** CPU, RAM, GPU, disk, network and temperature information.
- **User Menu:** user-related actions and information.

### Clipboard

A dedicated interface for clipboard interaction and history management.

### Application Launcher

An integrated application launcher designed to provide quick access to installed applications.

---

## Technology Stack

| Technology | Purpose |
|:---|:---|
| [Rust](https://www.rust-lang.org/) | Backend and system operations |
| [Quickshell](https://quickshell.org/) | Desktop shell framework |
| [QML](https://doc.qt.io/qt-6/qmlapplications.html) | Interface composition and interaction |
| [Qt Quick](https://doc.qt.io/qt-6/qtquick-index.html) | UI components and rendering |
| [Cargo](https://doc.rust-lang.org/cargo/) | Dependency and build management |

## Architecture

Wayck follows a feature-oriented architecture, keeping interface components organized by responsibility and shared services centralized.

```text
wayck/
├── docs/
│   ├── bar.png
│   ├── clipboard.png
│   └── launcher.png
├── hypr/
├── qml/
│   ├── shell.qml
│   ├── features/
│   │   ├── bar/
│   │   │   ├── Bar.qml
│   │   │   ├── BarConfig.qml
│   │   │   ├── components/
│   │   │   └── modules/
│   │   ├── clipboard/
│   │   │   └── Clipboard.qml
│   │   └── launcher/
│   │       └── Launcher.qml
│   └── services/
├── src/
├── Cargo.toml
├── Cargo.lock
├── build.sh
├── install.sh
└── README.md
```

### Design Principles

- **Feature isolation:** each interface has its own dedicated directory.
- **Centralized services:** shared functionality stays in one location.
- **Modularity:** individual bar modules can be maintained independently.
- **Separation of concerns:** QML handles presentation and interaction, while Rust handles backend operations.
- **Maintainability:** a consistent structure avoids unnecessary directory fragmentation.

---

## Requirements

- Linux
- Rust and Cargo
- Quickshell
- Qt dependencies required by Quickshell
- Hyprland for Hyprland-specific integrations

## Installation

### Automatic Installation

The recommended installation method uses the included installer.

```bash
git clone https://github.com/DuckCosmos/wayck.git
cd wayck

chmod +x install.sh
./install.sh
```

### Direct Installation

If you prefer to install Wayck directly, follow these steps.

**Execute this command**

```bash
curl -fsSL https://raw.githubusercontent.com/DuckCosmos/wayck/main/install.sh | bash
```

### Manual Installation

But, if you prefer to install Wayck manually, follow these steps.

**1. Clone the repository**

```bash
git clone https://github.com/DuckCosmos/wayck.git
cd wayck
```

**2. Build the Rust backend**

```bash
cargo build --release --bins
```

**3. Create the Quickshell configuration directory**

```bash
mkdir -p ~/.config/quickshell/wayck
```

**4. Copy the QML configuration**

```bash
cp -r qml/* ~/.config/quickshell/wayck/
```

**5. Install the backend binaries**

Install the generated binaries in the location expected by the project's QML services and scripts. Check `install.sh` for the exact deployment paths.

**6. Start Wayck**

```bash
quickshell -c wayck
```

---

## Building from Source

Check all Rust binaries:

```bash
cargo check --bins
```

Build all binaries in release mode:

```bash
cargo build --release --bins
```

Run the project build script:

```bash
chmod +x build.sh
./build.sh
```

## Running

After installation, start Wayck with:

```bash
quickshell -c wayck
```

The installed Quickshell configuration is expected at:

```text
~/.config/quickshell/wayck
```

## Project Structure

| Directory | Responsibility |
|:---|:---|
| `src/` | Rust backend |
| `qml/` | QML application |
| `qml/features/bar/` | Desktop bar and its modules |
| `qml/features/clipboard/` | Clipboard interface |
| `qml/features/launcher/` | Application launcher |
| `qml/services/` | Shared QML services |
| `hypr/` | Hyprland configuration |
| `docs/` | Documentation and screenshots |

## Development

Wayck is organized to allow independent development of its interface features and backend.

| Component | Location |
|:---|:---|
| Main entry point | `qml/shell.qml` |
| Desktop Bar | `qml/features/bar/` |
| Bar modules | `qml/features/bar/modules/` |
| Bar components | `qml/features/bar/components/` |
| Clipboard | `qml/features/clipboard/` |
| Launcher | `qml/features/launcher/` |
| Shared services | `qml/services/` |
| Rust backend | `src/` |

### Development Commands

```bash
# Check Rust binaries
cargo check --bins

# Build in release mode
cargo build --release --bins

# Run the build script
./build.sh
```

## Contributing

Contributions, bug reports and suggestions are welcome.

When contributing, please follow the existing architecture:

- Keep feature-specific components inside their respective directories.
- Place shared functionality in `qml/services/`.
- Avoid duplicated services and unnecessary abstractions.
- Keep backend responsibilities separate from interface presentation.
- Maintain consistent naming and organization.
- Test changes before submitting contributions.

## License

See the repository for licensing information.

---

**Wayck** — Built with Rust, Quickshell and QML.