# Monitor Alignment Calibration Log

This document tracks the optimal vertical alignment for the Desktop Truck Simulator across different hardware configurations.

| Date | Monitor Resolution | Display Scale | Usable Height | Taskbar Height | Vertical Offset | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-05-05 | 3440 x 1440 | 1.0 (100%) | 1392 px | 48 px | **-192** | Perfect mathematical alignment (1/2 asset height). |

## Parameter Definitions

- **Monitor Resolution**: Total physical pixels of the primary display.
- **Display Scale**: OS-level scaling factor (e.g., 1.0 = 100%, 1.25 = 125%).
- **Usable Height**: Total height minus the taskbar (detected via `screen_get_usable_rect`).
- **Vertical Offset**: The value set in `scripts/Main.gd` to align wheels to the taskbar.
  - *Negative*: Moves truck DOWN (into the taskbar/off-screen).
  - *Positive*: Moves truck UP (away from the taskbar).
