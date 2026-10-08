# FocusFlow

A focus timer for the [Omarchy](https://omarchy.org) bar: an orbital pomodoro dial, a small task list you can link to sessions, a weekly activity chart, and an optional distraction shield that reacts when blocked sites show up during focus.

Everything follows your Omarchy theme and font.

## Install

```sh
omarchy plugin add https://github.com/zaki2993/focusflow.git --enable
```

Plugins land disabled unless you pass `--enable`. To enable later, or move the widget:

```sh
omarchy plugin enable zakarch.focusflow
omarchy bar move zakarch.focusflow --section right
```

Update with `omarchy plugin update zakarch.focusflow`; remove with `omarchy plugin remove zakarch.focusflow`.

## Using it

The bar shows the remaining time while a session runs, and the number of open tasks while idle.

| On the bar widget | Does |
| --- | --- |
| Left-click | Open / close the panel |
| Middle-click | Pause / resume |
| Right-click | Reset the session |

The panel has three views:

- **Focus**: start, pause, resume or reset; start a break; complete the linked task. Pips under the dial track today's sessions against your daily goal.
- **Tasks**: add tasks, tick them off, and click a title to link it to the timer. Completed focus sessions are counted on the linked task. **⋯** opens priority, edit, link and delete. **Options** sets the priority for new tasks and the sort order. You can also type a priority inline: `Write report !high`.
- **Settings**:
  - **General**: presets (25/5, 50/10, 90/20), focus and break length, daily goal, auto-start, alert style (notification or full-screen), and sounds.
  - **Shield**: distraction shield settings (see below).
  - **Activity**: today / week / month / blocked counts and the last 7 days.

### Keyboard

| Key | Does |
| --- | --- |
| `Space` / `Enter` / `S` / `P` | Start or pause (Focus view) |
| `R` | Reset the session |
| `1` `2` `3` | Focus, Tasks, Settings |
| `←` `→` | Switch view (or settings page) |
| `Tab` | Move between controls; `Space`/`Enter` activates |
| `Esc` | Close |

Shortcuts are ignored while you type in a text field.

## Distraction shield

While a focus session runs, FocusFlow watches browser and web-app windows (Chromium, Brave, Firefox, Zen, and similar, including Omarchy web apps) and matches them against your blocked list by window class and title. Terminals, editors and file managers are never touched.

When a blocked site appears, it can:

- **Notify** (default): a reminder, once per window per session.
- **Switch away**: jump back to your previous workspace.
- **Close**: close the matching window. This closes the whole browser window, including other tabs in it.

**Scan when focus starts** also checks windows that are already open. Matching uses window titles, so a site is only recognised when its name or domain appears in the title. The shield is a nudge, not a lock.

## Command line

The service and panel answer IPC through `omarchy-shell`:

```sh
omarchy-shell zakarch.focusflow startFocus      # also: startBreak, pause, resume, reset, skip
omarchy-shell zakarch.focusflow nudge 5         # add (or subtract) minutes
omarchy-shell zakarch.focusflow addTask "Write report"
omarchy-shell zakarch.focusflow status          # JSON snapshot
omarchy-shell zakarch.focusflow addPresetApp youtube
omarchy-shell zakarch.focusflow setBlockerAction notify   # notify | switch | close

omarchy-shell zakarch.focusflow.widget toggle
omarchy-shell zakarch.focusflow.widget settings shield    # general | shield | activity
```

Bind them to keys in `~/.config/hypr/bindings.lua`, for example:

```lua
o.bind("SUPER + ALT + F", "FocusFlow", hl.dsp.exec_cmd("omarchy-shell zakarch.focusflow.widget toggle"))
```

## Data

State lives in `~/.local/state/omarchy/zakarch.focusflow.json`: settings, tasks, completed-session dates (kept for 400 days), and the running timer, so a shell restart keeps your session. Nothing leaves your machine.

## Requirements

- Omarchy with the Quickshell-based shell and Hyprland (Lua config)
- `pw-play` (PipeWire, installed by default) for sounds; `paplay` or `canberra-gtk-play` also work

## License

MIT. Date helpers adapted from `lucas.pomodoro`.
