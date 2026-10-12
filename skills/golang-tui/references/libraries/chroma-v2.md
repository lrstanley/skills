# Chroma v2

Code syntax highlighting for terminal UIs. Import: `github.com/alecthomas/chroma/v2`

Use when rendering source code, configuration files, or any syntax-highlighted content
in a viewport or panel.

## Basic Highlighting (Without bubbletint)

```go
import (
    "bytes"
    "strings"

    "github.com/alecthomas/chroma/v2"
    "github.com/alecthomas/chroma/v2/formatters"
    "github.com/alecthomas/chroma/v2/lexers"
    "github.com/alecthomas/chroma/v2/styles"
)

func highlightCode(source, language string) (string, error) {
    lexer := lexers.Get(language)
    if lexer == nil {
        lexer = lexers.Fallback
    }
    lexer = chroma.Coalesce(lexer)

    style := styles.Get("dracula")
    if style == nil {
        style = styles.Fallback
    }

    formatter := formatters.Get("terminal256")
    if formatter == nil {
        formatter = formatters.Fallback
    }

    iterator, err := lexer.Tokenise(nil, source)
    if err != nil {
        return "", err
    }

    var buf bytes.Buffer
    if err := formatter.Format(&buf, style, iterator); err != nil {
        return "", err
    }
    return buf.String(), nil
}
```

### Choosing a Formatter

- `"terminal256"` -- ANSI 256-color output, widest compatibility
- `"terminal16m"` -- TrueColor output, best quality
- `"terminal"` -- ANSI 16-color, most basic

Select based on detected terminal capabilities (when using lipgloss/bubbletea):

```go
func formatterForProfile(profile colorprofile.Profile) string {
    switch profile {
    case colorprofile.TrueColor:
        return "terminal16m"
    case colorprofile.ANSI256:
        return "terminal256"
    default:
        return "terminal"
    }
}
```

## Highlighting with bubbletint

bubbletint includes a `chromatint` package that generates a chroma `Style` from
the active tint, keeping syntax highlighting consistent with the terminal theme.

```go
import (
    "github.com/alecthomas/chroma/v2"
    "github.com/lrstanley/bubbletint/chromatint/v2"
    tint "github.com/lrstanley/bubbletint/v2"
)

func chromaStyleFromTint(t tint.Tint) *chroma.Style {
    cs, err := chroma.NewStyle("myapp", chromatint.StyleEntry(t, false))
    if err != nil {
        return styles.Fallback
    }
    return cs
}
```

The second argument to `StyleEntry` controls whether the background is transparent
(`true`) or uses the tint background (`false`).

## When to Use

- Code or configuration file previews in a viewport
- Syntax-highlighted diffs
- Log file rendering with language-aware coloring

## When Not to Use

- Simple colored text (use lipgloss styles instead)
- Small inline code snippets where full lexing is overhead
