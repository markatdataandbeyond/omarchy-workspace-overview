# Workspace Overview

Four workspaces. Four keys. That's the map.

A fullscreen 2×2 overview of the workspaces you actually have open. Live
miniatures of the real tile layout. Trackpad opens it. Number keys leave it.

- **4-finger swipe up** or Super + the key left of `1` toggles the map
- **`1`–`0`** jump to that workspace
- **Arrows** / **J K** move the selection; **Enter** goes
- **Esc** closes without moving
- More than four open workspaces? Scroll to the next row

Empty workspaces stay off the map. Scratchpads stay off the map. There are no
settings.

## Install

```sh
omarchy plugin add https://github.com/markatdataandbeyond/omarchy-workspace-overview --enable
```

Toggle it:

```sh
omarchy-shell shell toggle mpb.workspace-overview '{}'
```

## Bindings

In `~/.config/hypr/input.lua`:

```lua
hl.gesture({ fingers = 4, direction = "up", action = function()
  hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell toggle mpb.workspace-overview '{}'"))
end })
```

In `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + code:49", "Workspace overview", "omarchy-shell shell toggle mpb.workspace-overview '{}'")
```

## Requirements

Hyprland with `hyprland_toplevel_export_manager_v1` and Omarchy's Lua config
provider.

## Tests

```sh
./test/all
```

## License

[MIT](LICENSE)
