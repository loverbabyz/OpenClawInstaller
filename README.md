# OpenClaw Installer

A native macOS installer application for [OpenClaw](https://github.com/nicepkg/openclaw), built with SwiftUI.

## Features

- **Guided Installation** — Step-by-step wizard that walks you through the entire OpenClaw setup process
- **Multiple Install Methods** — Support for npm (recommended) and git (source) installation
- **Dependency Management** — Automatic detection and installation of prerequisites (Homebrew, Node.js v22+, Git, pnpm)
- **Configuration Wizard** — Comprehensive setup for 40+ LLM providers, authentication, channels, hooks, skills, and more
- **Gateway Setup** — Configure and install the OpenClaw gateway daemon with health checks
- **Doctor Diagnostics** — Built-in diagnostic tool to verify and fix your OpenClaw installation
- **Config Editor** — Edit `~/.openclaw/openclaw.json` via a dedicated GUI window

## Screenshots

The installer features a dark-themed UI with a 680×720 fixed window and a step indicator showing progress through six stages: Welcome → Method → Dependencies → Install → Configure → Complete.

## Requirements

- macOS 13.0+
- Xcode 15.0+

## Build

```bash
# Open in Xcode
open OpenClawInstaller.xcodeproj

# Or build from command line
xcodebuild -project OpenClawInstaller.xcodeproj -scheme OpenClawInstaller -configuration Release
```

## Project Structure

```
OpenClawInstaller/
├── OpenClawInstallerApp.swift    # App entry point
├── ContentView.swift             # Main view with step navigation
├── ViewModels/
│   └── InstallerViewModel.swift  # Core business logic
├── Views/
│   ├── WelcomeView.swift         # System detection & uninstall
│   ├── MethodSelectionView.swift # npm vs git selection
│   ├── DependencyCheckView.swift # Prerequisite checks
│   ├── InstallProgressView.swift # Installation progress
│   ├── ConfigEditorView.swift    # Configuration GUI
│   ├── CompletionView.swift      # Final step & launch
│   ├── DoctorView.swift          # Diagnostics
│   └── OnboardingView.swift      # Config wizard sub-steps
└── Helpers/
    └── ShellExecutor.swift       # Shell command execution
```

## License

MIT
