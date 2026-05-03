
# Godot QuickStart Template

[![itch.io](https://img.shields.io/badge/itch.io-Live%20Demo-3eff6a?logo=itch.io)](https://hubacekjakub.itch.io/godot-quick-start)
[![CI Status](https://github.com/hubacekjakub/Godot-QuickStart/actions/workflows/main.yml/badge.svg)](https://github.com/hubacekjakub/Godot-QuickStart/actions/workflows/main.yml)
[![Build Status](https://github.com/hubacekjakub/Godot-QuickStart/actions/workflows/main.yml/badge.svg)](https://github.com/hubacekjakub/Godot-QuickStart/actions/workflows/main.yml)
[![Latest Release](https://img.shields.io/badge/GitHub-Release-blue?logo=github)](https://github.com/hubacekjakub/Godot-QuickStart/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/hubacekjakub/Godot-QuickStart/blob/main/LICENSE)
[![Godot 4.6](https://img.shields.io/badge/Godot-4.6-blue)](https://godotengine.org/)

**My personal Godot 4.6 template with automated CI/CD and itch.io deployment.** Speed up development and deployment of any Godot project.

🎮 **[Try Live Demo](https://hubacekjakub.itch.io/godot-quick-start)**

## ✨ What Makes This Special

This template eliminates the tedious setup work for modern Godot development:
- **Zero-config CI/CD** - Works out of the box with GitHub Actions
- **Production-ready workflow** - Used for real game releases
- **Developer-friendly** - VS Code integration with proper debugging
- **One-tag deployment** - Push `v1.0.0` and your game is live on itch.io

Perfect for game jams, prototypes, or serious indie projects!

## 🚀 Quick Start

1. **Fork** this repository → **Clone** your fork → **Open** in Godot
2. **Press F5** to run • **Replace the ball** with your game
3. **Optional:** Set up [itch.io deployment](#-automated-deployment) for one-click publishing

**Controls:** WASD/Arrows to move • Escape to quit

## ⚡ Features

- **Complete CI/CD Pipeline** - Push a tag, get automatic builds + itch.io deployment
- **Multi-Platform Builds** - Windows, Linux, Web exports on every release
- **VS Code Integration** - Debugging, tasks, and launch configurations included
- **Professional Structure** - Organized folders, export presets, proper gitignore

## 🤖 Automated Deployment

### One-Command Release
```bash
git tag v1.0.0 && git push origin v1.0.0
# → Automatic build + GitHub release + itch.io deployment!
```

### Deployment Setup
Add these GitHub secrets for itch.io deployment:
- **`BUTLER_API_KEY`** - Get from https://itch.io/user/settings/api-keys
- **`ITCH_USERNAME`** - Your itch.io username
- **`ITCH_GAME_NAME`** - Your game project name (e.g., `godot-quick-start`)

**Example:** This demo was deployed automatically: https://hubacekjakub.itch.io/godot-quick-start

### What Happens Automatically
1. **Validation** - GDScript syntax check and project verification
2. **Build** - Creates Windows .exe, Linux executable, and Web build
3. **Release** - GitHub release with downloadable files
4. **Deploy** - Web version automatically published to itch.io
5. **Notify** - Build status and links in GitHub Actions

## 📁 Project Structure

```
├── scenes/          # Game scenes (.tscn)
├── levels/          # Main game levels
├── scripts/         # GDScript files (.gd)
├── assets/          # Fonts, sounds, textures
├── .vscode/         # VS Code integration
└── .github/         # CI/CD workflows
```

## 🔧 VS Code Features

- **Tasks:** Run Godot Project, Run Game, Debug modes
- **Debugging:** Breakpoints, step-through, remote debug
- **Launch configs:** F5 to start debugging sessions

## 📝 License

This project is licensed under the [MIT License](LICENSE).
You are free to use, modify, and distribute this template in your own projects.

---

**💡 Pro Tip:** Star this repo if it helps your workflow! Questions? Open an issue or check the [live demo](https://hubacekjakub.itch.io/godot-quick-start) to see everything working.
