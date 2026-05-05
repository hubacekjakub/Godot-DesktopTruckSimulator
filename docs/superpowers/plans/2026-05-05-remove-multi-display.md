# Remove Multi-Display Functionality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revert the multi-display functionality while preserving code cleanup, type hints, and bug fixes introduced in recent commits.

**Architecture:** Modify `_update_desktop_bounds()` in `Main.gd` to only consider the primary screen (index 0) instead of iterating over all screens. This ensures the truck stays on one display while keeping the improved movement logic and window configuration.

**Tech Stack:** GDScript (Godot 4.x)

---

### Task 1: Modify Desktop Bounds Calculation

**Files:**
- Modify: `scripts/Main.gd`

- [ ] **Step 1: Update `_update_desktop_bounds()` to only use screen 0**

```gdscript
## Calculates the bounding box of the primary screen and updates _desktop_rect.
func _update_desktop_bounds() -> void:
	var screen_idx = 0 # Always use primary screen
	var pos = DisplayServer.screen_get_position(screen_idx)
	var size = DisplayServer.screen_get_size(screen_idx)

	_desktop_rect = Rect2i(pos.x, pos.y, size.x, size.y)
```

- [ ] **Step 2: Commit changes**

```bash
git add scripts/Main.gd
git commit -m "feat: restrict truck movement to primary display"
```

### Task 2: Remove Temporary Documentation

**Files:**
- Delete: `todo.md`

- [ ] **Step 1: Remove `todo.md`**

Run: `rm todo.md`

- [ ] **Step 2: Commit changes**

```bash
git add todo.md
git commit -m "cleanup: remove temporary todo file"
```

### Task 3: Validation

- [ ] **Step 1: Run the project and verify truck movement**

Run: `godot --path .`
Verify: Truck stays within the bounds of the primary monitor and doesn't cross into other displays (if present).
