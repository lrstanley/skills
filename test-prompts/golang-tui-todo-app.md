I'd like to create a bubbletea-based TUI for managing TODOs

features:
- fullscreen app
- vertical list of todos
- box at the top to add a new todo
  - pressing escape should re-select this input field and unfocus everything else
  - when adding a todo, there should be an option to open up a full view where you can add more details -- a title input, and a larger description box for filling in multi-line text
  - dedicated view for adding a todo should have a cancel/create that is switchable (tab, shift+tab to go in the inverse direction)
- ability to edit todos that were previously created
- ability to mark todos as complete, with a visual indicator (e.g. a checkmark, strikethrough, etc)
- ability to delete todos with a confirmation dialog
- ability to expand todos to show more detail (e.g. if truncated/smaller screen)
- ability to use up/down (& j/k) when quick-add input is focused but empty, to swap to existing todos
- splash screen with a gradient/blend effect (1s duration)
- 1 cell tall statusbar at the bottom with "Todoer" in the bottom left, the number of todo's next to that, and a silly quote on the right that rotates every 10 seconds.
- use bubbletint for the theme -- pick a color scheme that works well on dark terminal backgrounds
- use nerdfonts, with fallbacks
- use lrstanley/clix (v2) for the cli flags
- don't add tests
- keep todos in-memory for the initial implementation


make sure to use /golang /golang-tui and /tui-design
