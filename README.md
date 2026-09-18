# Workspace Overview

Omarchy is a keyboard system, and that's the point. But sometimes the laptop
is on the couch, or you're just browsing, or you only have one hand free.
Reaching for the mouse feels like giving up. The trackpad is already under
your thumb.

This plugin is for that. Four fingers across the pad moves you between
workspaces. Three fingers does the tab things you'd otherwise chord. None of
it asks you to hunt for a pointer.

The other time it earns its keep is the opposite problem: two hands on the
keyboard, and you still can't remember where you left something. Slack on 3?
The browser on 2? Four fingers up — or Super and the key left of 1 — and you
see the workspaces you actually have open, as they really look. Wallpaper in
the gaps, windows in their real layout. You know what's where. Hit the number
and you're there.

Empty desks stay off the map. Scratchpads too. If you've got more than four
workspaces open, scroll. There's nothing to configure.

## Install

```sh
omarchy plugin add https://github.com/markatdataandbeyond/omarchy-workspace-overview --enable
```

Then add the binds below, or call it yourself:

```sh
omarchy-shell shell toggle mpb.workspace-overview '{}'
```

## Bindings

In `~/.config/hypr/input.lua`:

```lua
hl.gesture({
  fingers = 4,
  direction = "up",
  action = function()
    hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell summon mpb.workspace-overview '{}'"))
  end,
})
hl.gesture({
  fingers = 4,
  direction = "down",
  action = function()
    hl.dispatch(hl.dsp.exec_cmd("omarchy-shell shell hide mpb.workspace-overview"))
  end,
})
```

Four fingers left/right can be Hyprland's built-in workspace swipe. Three-finger
tab shortcuts are optional and live in the same file.

In `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + code:49", "Workspace overview", "omarchy-shell shell toggle mpb.workspace-overview '{}'")
```

Once it's open: `1`–`0` jumps, arrows or J/K move, Enter goes, Esc or four
fingers down closes.

## Requirements

Hyprland with `hyprland_toplevel_export_manager_v1` and Omarchy's Lua config
provider.

## Tests

```sh
./test/all
```

## License

[MIT](LICENSE)
