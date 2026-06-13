# Match music

Drop real music files here (`.ogg`, `.mp3`, or `.wav`) and they play during
matches — shuffled, with a fade-in, advancing to the next track when one ends.
Menus use the sibling `menu/` folder instead.

The folder ships empty: matches are silent (SFX only) until you add a file.
Pick calmer/atmospheric loops here so they don't fight the game sounds — and
remember the in-game Music volume slider scales these.

`.ogg` is the best fit for Godot. After adding files, let Godot import them
(open the editor once, or run `--headless --import`).
