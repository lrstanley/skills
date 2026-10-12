# Terminal Images and Raster in Go

Bitmap and rich-pixel output in terminals uses several incompatible protocols. The
Charm `github.com/charmbracelet/x` module provides helpers; Bubble Tea has no
built-in image widget, so you build escape sequences and place them in the View (or
send with `tea.Raw`).

## When to Use

- **Sixel or Kitty** when you need true pixels and the terminal supports them (often
  kitty, WezTerm, Ghostty, mlterm, xterm with sixel).
- **iTerm2 OSC 1337** when targeting iTerm2, WezTerm, or other emulators that
  implement the same inline image protocol.
- **Mosaic** when you want a **unicode block** preview that works in any UTF-8
  terminal without sixel or Kitty (lower fidelity, widest compatibility).

## When Not to Use

- **SSH through old multiplexers** without passthrough: sequences may be stripped.
- **Latency-sensitive TUIs** where large base64 blobs or sixel bands hurt frame time;
  prefer thumbnails, mosaic, or file open in a GUI viewer.
- **Assuming one protocol**: offer a user setting or detect terminal (best-effort).

## Package Map

Shorthand `x/ansi/...` means `github.com/charmbracelet/x/ansi/...`.

| Protocol | Role | Packages |
| --- | --- | --- |
| Sixel | DCS sixel raster | `github.com/charmbracelet/x/ansi` (`SixelGraphics`), `github.com/charmbracelet/x/ansi/sixel` |
| Kitty | APC Kitty graphics | `github.com/charmbracelet/x/ansi` (`KittyGraphics`), `github.com/charmbracelet/x/ansi/kitty` |
| iTerm2 inline images | OSC 1337 | `github.com/charmbracelet/x/ansi` (`ITerm2`), `github.com/charmbracelet/x/ansi/iterm2` |
| Mosaic | Unicode blocks from `image.Image` | `github.com/charmbracelet/x/mosaic` |

## Sixel: Encoder plus DCS Wrapper

`ansi.SixelGraphics` wraps raw sixel **payload** (the bytes after `q` in the DCS).
The `sixel.Encoder` writes that payload (palette plus raster data).

```go
import (
    "bytes"
    "image"
    "image/png"
    "os"

    "github.com/charmbracelet/x/ansi"
    "github.com/charmbracelet/x/ansi/sixel"
)

func sixelSequence(img image.Image) (string, error) {
    var payload bytes.Buffer
    var enc sixel.Encoder
    if err := enc.Encode(&payload, img); err != nil {
        return "", err
    }
    // p1: aspect ratio (often 0). p2: use 1 to avoid black bars on many terminals.
    // p3: grid parameter (0 lets encoder set metrics in payload).
    return ansi.SixelGraphics(0, 1, 0, payload.Bytes()), nil
}

func loadPNG(path string) (image.Image, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer f.Close()
    return png.Decode(f)
}
```

## Kitty: High-Level Encode

Prefer `kitty.EncodeGraphics` to handle base64 chunking and `ansi.KittyGraphics`
internally. Use `kitty.Options` for format, direct vs file transmission, and
chunking for large images.

```go
import (
    "bytes"
    "image"
    "image/color"

    "github.com/charmbracelet/x/ansi/kitty"
)

func kittySequence(img image.Image) (string, error) {
    var buf bytes.Buffer
    opts := &kitty.Options{
        Transmission: kitty.Direct,
        Format:       kitty.RGBA,
    }
    if err := kitty.EncodeGraphics(&buf, img, opts); err != nil {
        return "", err
    }
    return buf.String(), nil
}

func tinyRGBA() image.Image {
    img := image.NewRGBA(image.Rect(0, 0, 2, 2))
    img.Set(0, 0, color.RGBA{R: 255, A: 255})
    img.Set(1, 1, color.RGBA{B: 255, A: 255})
    return img
}
```

See `kitty.Options` for `Action`, placement IDs, and chunking. Defaults pick
`Transmit` with direct RGBA data; adjust when you split transmit vs display steps.

## Kitty: Low-Level `KittyGraphics`

If you already have **base64-encoded** payload bytes matching the protocol, you can
emit sequences directly:

```go
import "github.com/charmbracelet/x/ansi"

// Payload must match what the terminal expects for the given opts (often base64).
seq := ansi.KittyGraphics(payload, "f=32", "s=10", "v=10")
```

## iTerm2 Inline Image (OSC 1337)

Build an `iterm2.File` with **base64** body in `Content`. Many terminals that speak
this protocol accept `inline=1` for display inside the scrollback.

```go
import (
    "encoding/base64"
    "os"

    "github.com/charmbracelet/x/ansi"
    "github.com/charmbracelet/x/ansi/iterm2"
)

func iterm2Sequence(pngPath string) (string, error) {
    raw, err := os.ReadFile(pngPath)
    if err != nil {
        return "", err
    }
    b64 := base64.StdEncoding.EncodeToString(raw)
    f := iterm2.File{
        Name:   pngPath,
        Width:  iterm2.Cells(40),
        Height: iterm2.Auto,
        Inline: true,
        Content: []byte(b64),
    }
    return ansi.ITerm2(f), nil
}
```

`DoNotMoveCursor` is a WezTerm extension; test before relying on it.

## Mosaic: Unicode Block Art

Renders an `image.Image` to block characters (half, quarter, etc.). No sixel or
Kitty required; the renderer applies ANSI colors itself (truecolor SGR). You can
still wrap the result with lipgloss for layout if you account for width.

```go
import (
    "image"
    "image/png"
    "os"

    "github.com/charmbracelet/x/mosaic"
)

func mosaicString(img image.Image, cellWidth, cellHeight int) string {
    m := mosaic.New().Width(cellWidth).Height(cellHeight)
    return (&m).Render(img)
}

func mosaicFromFile(path string, w, h int) (string, error) {
    f, err := os.Open(path)
    if err != nil {
        return "", err
    }
    defer f.Close()
    img, err := png.Decode(f)
    if err != nil {
        return "", err
    }
    return mosaic.Render(img, w, h), nil
}
```

## Bubble Tea: Embed in the View

Concatenate the sequence string into your layout. The renderer treats it as output
bytes; lipgloss can sit beside it if you account for width (images often break
`lipgloss.Width` assumptions).

```go
import tea "charm.land/bubbletea/v2"

type model struct {
    art string // precomputed mosaic or protocol string
}

func (m model) View() tea.View {
    return tea.NewView("preview:\n\n" + m.art)
}
```

## Bubble Tea: `tea.Raw`

Returns a command whose `tea.RawMsg` carries data the runtime writes to the terminal
with minimal processing. Prefer embedding sequences in `View` when possible.

```go
import "github.com/charmbracelet/x/ansi"

// Example: query capabilities (not specific to images, same Raw pathway).
return m, tea.Raw(ansi.RequestPrimaryDeviceAttributes)
```

Pass the same escape strings you would emit for Kitty, sixel, or OSC sequences when
you need them outside the View pass.

## Testing

- **Golden snapshots**: capture protocol strings only in tests that pin `TERM` and
  a documented terminal profile, or mock the encoder output.
- **Mosaic**: output includes ANSI color sequences (truecolor SGR) around block or
  space characters, not plain UTF-8 alone. Snapshot the full string and pin the
  `github.com/charmbracelet/x/mosaic` version, or assert on invariants (non-empty,
  contains escape introducer) instead of unicode-only snapshot files.
- **Sixel/Kitty/iTerm2**: binary-heavy strings; prefer testing `Encode` helpers and
  small fixed `image.Image` fixtures rather than full PNGs.

## References

- [Kitty graphics](https://sw.kovidgoyal.net/kitty/graphics-protocol/)
- [iTerm2 images](https://iterm2.com/documentation-images.html)
- [Sixel background](https://shuford.invisible-island.net/all_about_sixels.txt)
