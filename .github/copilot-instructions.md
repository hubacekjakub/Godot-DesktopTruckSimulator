This repo uses Godot 4.x with GDScript. Keep guidance generic and portable so it works across machines and platforms.

## Code Style
- Use snake_case for variables and functions, PascalCase for classes and enums, and SCREAMING_SNAKE_CASE for constants.
- Use @onready for node references accessed in _ready().
- Prefer explicit typing when beneficial (e.g., `var player: Player`).

## Project Structure
- **Scenes (.tscn)**
	- Place level/root scenes in a `levels/` directory.
	- Put reusable/component scenes under `scenes/` (subfolders like `characters/`, `interactables/`, `ui/`, etc.).
- **Scripts (.gd)**
	- Store gameplay and UI scripts under `scripts/` mirroring the scene layout when practical.
- **Assets**
	- Keep raw art/audio in `assets/` and commit Godot import sidecars (`*.import`).
- **Deprecated**
	- Move temporarily unused content to `deprecated/` instead of deleting immediately.

## Running Locally
- Use the VS Code task "Run Godot Project" to open the Godot editor for scene creation.
- Use the VS Code task "Run Game" for quick testing without the editor.
- Avoid committing machine-specific paths; rely on tasks and repo-relative paths.

## Repo Hygiene
- Ignore the `.godot/` folder and other generated artifacts.
- Keep `export_presets.cfg` under version control to share export settings when applicable.
- Do not hard-code absolute paths in project or settings files.
