# FocusFlow Studio

A compact, theme-aware focus timer with an orbital dial, tasks, and optional distraction shielding.

## Use

Click the Studio widget in your bar.

- **Focus:** start, pause, resume, reset, or take a break. Choose a linked task using the task strip; tick it when finished.
- **Tasks:** add tasks and tick completed ones. Click a title to link/unlink it with the focus timer. Open **⋯** for editing, priority, linking, and deletion. **Options** contains new-task priority and sorting.
- **Settings:** three pages, switched with the segmented control at the top (or ←/→).
  - **General:** timer presets (25/5, 50/10, 90/20), focus and break lengths, daily goal; auto-start breaks and focus; reminder style (notification or full-screen); session and task sounds.
  - **Shield:** master switch, what happens when a blocked site appears (notify, switch away, close), scan-on-start, the blocked-website list with per-site switches, quick-add presets, and a confirm-to-restore default list. Options dim while the shield is off.
  - **Activity:** today/week/month/blocked counts and the weekly chart.

Space starts/pauses; 1 opens Focus, 2 opens Tasks, 3 opens Settings; Escape closes. In Settings, ←/→ switches pages. Shortcuts yield to text fields and focused controls. Tab navigates controls; Space or Enter toggles a focused switch. Middle-click the bar widget to pause/resume; right-click to reset.

Open a settings page directly: `omarchy-shell zakarch.focusflow-studio.widget settings shield` (`general`, `shield`, or `activity`).

Open directly:

```sh
omarchy-shell zakarch.focusflow-studio.widget open
```

## Data

On first launch, Studio imports `~/.local/state/omarchy/focusflow.json`. Subsequent changes save independently to `~/.local/state/omarchy/focusflow-studio.json`. The original plugin remains installed. Later changes in one plugin do not sync to the other. Studio has its own model, service, sound asset, and IPC targets and continues working if the original plugin is removed.

Studio persists running/paused timer state so shell reloads preserve a session. The activity chart uses real completed sessions; empty days stay empty.

## Design

- **Colour:** popup background, foreground, accent, borders, and control states come from Omarchy's live `Color` and `Style` tokens. Primary-button text automatically uses a contrasting colour on the accent.
- **Typography:** follows Omarchy's system font and text-size tokens.
- **Layout:** 360 logical pixels wide, content-sized height, with a 420-pixel Focus cap and 450-pixel cap for Tasks and a 520-pixel cap for Settings (longer pages scroll). Anchored below the bar widget; smaller screens are fitted automatically.
- **Components:** the orbital timer remains the visual centre. Task details appear on demand. Settings use Omarchy's native toggle switch. Weekly activity lives on the Activity settings page. Animation runs only while Focus is open and a timer is running.

## Validation

Validated the manifest and QML syntax. Inspected Focus, Tasks, basic Settings, Shield, More options, and Activity in the running shell; confirmed compact dimensions and preservation of user tasks, preferences, and timer state. An isolated headless check verified reactive colours and primary-button contrast for both light and dark themes without changing the desktop theme.

Licensed MIT; service/model adapted from the original Focus Flow plugin.
