# go-nf

Nerd Font icons for Go. Import: `github.com/lrstanley/go-nf`

Provides access to Nerd Font glyphs by name. Always pair with unicode fallbacks for
terminals without Nerd Fonts installed.

## Basic Usage

Using constants:

```go
import "github.com/lrstanley/go-nf/glyphs/fa" // package fa: Font Awesome class.

icon := fa.BirthdayCake
label := icon.String() + " Happy Birthday!"
```

Using strings:

```go
import icons "github.com/lrstanley/go-nf/glyphs/all" // "all" has helpers for all icon classes.

icon := icons.Get("fa-birthday-cake")
label := icon.String() + " Happy Birthday!"
```

## Auto-detection (installed Nerd Fonts)

The root package (`github.com/lrstanley/go-nf`, typically imported as `nf`) can probe
whether Nerd Fonts appear to be installed. This is **not** the same as knowing the
terminal is rendering a Nerd Font: fonts may be installed but not selected in the
emulator. Use detection to gate defaults or first-run prompts, not as a guarantee
that glyphs will display correctly.

```go
status, err := nf.DetectInstalled(context.Background())
if err != nil {
    // optional: log or degrade; detectors may partially fail before StatusNotInstalled
}
switch status {
case nf.StatusEnabled:
    // user forced on (env var parsed as true)
case nf.StatusDisabled:
    // user forced off (env var parsed as false)
case nf.StatusInstalled:
    // matched installed font names (OS APIs / fontconfig / common paths)
case nf.StatusNotInstalled:
    // no match; treat as no Nerd Fonts for UX purposes
}
```

**Override with env vars:** set one of `NERD_FONTS`, `NERDFONTS`, or `NF_FONTS` to
`true` or `false` so users can force enable or disable without relying on
auto-detection.

**Custom detectors:** pass `nf.DetectInstalled(ctx, nf.DetectorEnvVar("MYAPP_NERD_FONTS"), ...)`
or build a slice starting from `nf.DefaultDetectors()` and prepend your own. Prefer
cheap checks (env, flags) before heavier ones (filesystem).

## Glyph class sub-packages

Icons are split under `github.com/lrstanley/go-nf/glyphs/<name>` by Nerd Font
**class** (and two special packages: `all`, `neo`). Import only the sets you need to
keep binaries smaller.

**Import template** (replace `<name>` with a package name from the list):

```go
import "github.com/lrstanley/go-nf/glyphs/<class>"

// For name collisions, you can use an alias:
import faicons "github.com/lrstanley/go-nf/glyphs/fa"
```

**Classes (may not include all):** `all`, `cod`, `custom`, `dev`, `extra`, `fa`, `fae`, `iec`,
`indent`, `indentation`, `linux`, `md`, `neo`, `oct`, `pl`, `ple`, `pom`, `seti`,
`weather`

- **`all`:** `Get("class-glyph-name")` style helpers across classes (larger API surface & binary size).
- **`neo`:** not a glyph class; see [neo package](#neo-package-nvim-tree-style-icons)
  below. It does not export the same constant-per-glyph pattern as `fa`, `md`, etc.

## neo package (nvim-tree style icons)

Import: `github.com/lrstanley/go-nf/glyphs/neo`

Lookup tables and helpers ported from [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)
mappings. Each resolved item includes a `nf.Glyph` plus **recommended colors** (truecolor and ANSI)
for light and dark backgrounds, matching nvim-tree conventions.

**Core type:** `neo.Result` exposes `Name()`, `Glyph()`, `String()`, `Color(dark bool)`,
and `ColorANSI(dark bool)` for styling file-type or OS lines in TUIs.

**Resolvers:**

| Use case | Functions |
| --- | --- |
| Full path or file name | `ByPath(path)`, `ByFileName(name)` |
| Extension only | `ByFileExtension(ext)` (with or without leading `.`) |
| OS | `ByOperatingSystem(name)`, `CurrentOS()` (uses `runtime.GOOS`; on Linux reads `/etc/os-release`) |
| Desktop / WM | `ByDesktopEnvironment(name)`, `ByWindowManager(name)` |

**Iteration:** `FileExtensions()`, `FileNames()`, `OperatingSystems()`,
`DesktopEnvironments()`, `WindowManagers()` return `iter.Seq2[string, neo.Result]`
over the embedded catalog (hundreds of file extensions and special-cased names).

**When to use `neo`:**

- File trees, pickers, or lists where the label is a **path** or **extension** and you
  want an icon (and optional tint) without maintaining your own map.
- Showing a **current OS** or environment glyph in a status or about view.

**When not to use `neo`:**

- You already know the glyph (use `glyphs/fa`, `glyphs/md`, etc.).
- You only need detection of whether Nerd Fonts are installed (use `nf.DetectInstalled`
  in the root package).
- You need the smallest dependency: `neo` pulls color and table data; prefer a
  minimal class import for a single static icon.

```go
import (
    "github.com/lrstanley/go-nf/glyphs/md"
    "github.com/lrstanley/go-nf/glyphs/neo"
)

func iconForPath(path string) string {
    r := neo.ByPath(path)
    if r == nil {
        return md.FileQuestion.String()
    }
    return r.String()
}
```

## Icon Fallback Pattern

Not all users have Nerd Fonts. Provide unicode fallbacks for every icon using a
capability check:

```go
var (
    IconFolder = iconFallback(fa.Folder, "\U0001F5BF")
    IconSecret = iconFallback(fa.Key, "\U0001F512")
    IconFilter = iconFallback(fa.Search, "\u2315")
    IconFlag   = iconFallback(fa.Flag, "\u2691")
)

func iconFallback(icon nf.Glyph, fallback string) func() string {
    return func() string {
        if !config.NerdFontsEnabled() {
            return fallback
        }
        return icon.String()
    }
}
```

Call as `IconFolder()` in your View code. The function checks a runtime flag so the
fallback decision can change without restart (e.g. if the user toggles Nerd Fonts
in settings). You can combine this with `nf.DetectInstalled` or config to set the
initial enabled flag.

## Standard Unicode Fallbacks

Icons that do not require Nerd Fonts can be defined as plain constants -- always make
sure to document what it is and why it is used:

```go
const (
    IconSeparator = "\u2022"  // Bullet -- used to separate items in a list.
    IconEllipsis  = "\u2026"  // ...
    IconRefresh   = "\u27F3"  // Clockwise Arrow -- used to refresh the data.
    IconScrollbar = "\u2503"  // Thick Vertical Line -- used to indicate a scrollable area.
)
```

These work in almost all terminals and do not need a fallback function.

## Configuration-Driven Enable/Disable

Store a boolean field in the user configuration file. On first run, if Nerd Fonts
are detected as installed, you can prompt the user to enable Nerd Fonts support.
Don't assume that because they are installed, they are enabled.

## Using Icons in Views

Combine icons with styled text:

```go
func (m model) renderItem(item Item, selected bool) string {
    icon := IconFolder()
    if item.Locked {
        icon = IconSecret()
    }

    label := fmt.Sprintf("%s %s", icon, item.Name)
    if selected {
        return selectedStyle.Render(label)
    }
    return itemStyle.Render(label)
}
```

## Common Nerd Font / Unicode Pairs

| Concept | Nerd Font | Unicode Fallback | Code Point |
| --- | --- | --- | --- |
| Folder | `fa-folder` | `\U0001F5BF` | U+1F5BF |
| Key/Secret | `fa-key` | `\U0001F512` | U+1F512 |
| Search/Filter | `fa-search` | `\u2315` | U+2315 |
| Flag | `fa-flag` | `\u2691` | U+2691 |
| Warning | `fa-exclamation-triangle` | `\u26A0` | U+26A0 |
| Check/Success | `fa-check` | `\u2713` | U+2713 |
| Error/Cross | `fa-times` | `\u2717` | U+2717 |
| Refresh | `fa-refresh` | `\u27F3` | U+27F3 |
| Clock | `fa-clock-o` | `\u231A` | U+231A |

## Guidelines

- Do not over-use icons. Only use a glyph when it is the clearest way to represent
  the concept (folder, lock, search, warning).
- Always provide a recognizable unicode fallback so the UI remains usable without
  Nerd Fonts.
- Test with Nerd Fonts disabled to verify fallbacks render correctly.
- Group icon definitions in a single file (e.g. `internal/ui/styles/constants.go`)
  for easy maintenance.
- Prefer widely-supported unicode characters for fallbacks. Test in common terminals
  (iTerm2, Windows Terminal, tmux, ghostty, kitty, etc).
