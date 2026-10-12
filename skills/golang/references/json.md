# JSON with `encoding/json/v2`

Import [`encoding/json/v2`](https://pkg.go.dev/encoding/json/v2) in new code. v1 remains supported and shares the v2 implementation; migrate only when touching call sites.

Skip when `chix.JSON` / `chix.Error` already encode responses. For token-level streaming, use [`encoding/json/jsontext`](https://pkg.go.dev/encoding/json/jsontext).

## Marshal and Unmarshal

```go
import "encoding/json/v2"

type User struct {
    ID    string `json:"id"`
    Email string `json:"email"`
    Age   int    `json:"age,omitzero"`
}

data, err := json.Marshal(User{ID: "u-1", Email: "a@example.com"})
if err != nil {
    return err
}

var u User
if err := json.Unmarshal(data, &u); err != nil {
    return err
}
```

Pass `Options` as variadic args: `json.OmitZeroStructFields(true)`, `json.RejectUnknownMembers(true)`, `jsontext.Multiline(true)`, `jsontext.AllowInvalidUTF8(true)`, `jsontext.AllowDuplicateNames(true)`.

## HTTP

Prefer `MarshalWrite` / `UnmarshalRead` over v1 `NewEncoder` / `NewDecoder`. `UnmarshalRead` consumes the entire reader.

```go
if err := json.UnmarshalRead(r.Body, &val); err != nil {
    http.Error(w, err.Error(), http.StatusBadRequest)
    return
}
w.Header().Set("Content-Type", "application/json")
_ = json.MarshalWrite(w, val)
```

## Struct tags

| Tag | Meaning |
| --- | --- |
| `omitzero` | Omit if Go zero (`IsZero()` when present) |
| `omitempty` | Omit if JSON would be null, `""`, `{}`, or `[]` |
| `string` | Numbers as JSON strings |
| `case:ignore` | Case-insensitive match; ignores `-` and `_` |
| `embed` | Promote field's JSON members into parent |

Prefer `omitzero` for types with a real zero value (`time.Time`, `netip.Addr`). Unexported fields: only `json:"-"`.

## v2 defaults

v2 rejects invalid UTF-8 and duplicate object names; field matching is case-sensitive. Opt into v1-like behavior with `jsontext.AllowInvalidUTF8(true)`, `jsontext.AllowDuplicateNames(true)`, `json.MatchCaseInsensitiveNames(true)`.

Custom types: implement `MarshalerTo` / `UnmarshalerFrom`, or use `json.MarshalFunc` / `json.UnmarshalFunc` for types you do not own.
