# Errors, Wrapping and Inspection

## Errors as Values

Go treats errors as ordinary values implementing the `error` interface:

```go
type error interface {
    Error() string
}
```

This means errors are returned, not thrown. Every function that can fail returns an `error` as its last return value, and every caller must check it.

```go
// ✗ Bad -- silently discarding errors
data, _ := os.ReadFile("config.yaml")

// ✗ Bad -- only checking in some branches
result, err := doSomething()
fmt.Println(result) // using result without checking err

// ✓ Good -- always check before using other return values
data, err := os.ReadFile("config.yaml")
if err != nil {
    return fmt.Errorf("reading config: %w", err)
}
```

## Error String Conventions

Error strings MUST be lowercase, without trailing punctuation, and should not duplicate the context that wrapping will add.

```go
// ✗ Bad -- capitalized, punctuation, redundant prefix
return errors.New("Failed to connect to database.")
return fmt.Errorf("UserService: failed to fetch user: %w", err)

// ✓ Good -- lowercase, no punctuation, concise
return errors.New("connection refused")
return fmt.Errorf("fetching user: %w", err)
```

When errors are wrapped through multiple layers, each layer adds its own prefix. The result reads like a chain:

```
creating order: charging card: connecting to payment gateway: connection refused
```

## Creating Errors

### `errors.New` -- static error messages

```go
var ErrNotFound = errors.New("not found")
var ErrUnauthorized = errors.New("unauthorized")
```

### `fmt.Errorf` -- dynamic error messages

```go
import "github.com/samber/oops"

// ✗ Avoid -- high-cardinality message, each user/tenant combo is a unique string
return fmt.Errorf("user %s not found in tenant %s", userID, tenantID)

// ✓ Prefer -- static message, variable data as structured attributes
return oops.With("user_id", userID).With("tenant_id", tenantID).Errorf("user not found")
```

### Decision table: which error strategy to use

| Situation | Strategy | Example |
| --- | --- | --- |
| Caller needs to match a specific condition | Sentinel error (`errors.New` as package var) | `var ErrNotFound = errors.New("not found")` |
| Caller needs to extract structured data | Custom error type | `type ValidationError struct { Field, Msg string }` |
| Error is purely informational, not matched on | `fmt.Errorf` or `errors.New` | `fmt.Errorf("connecting to %s: %w", addr, err)` |

## Custom Error Types

Create custom error types when callers need to extract structured data from errors.

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed on %s: %s", e.Field, e.Message)
}

// Usage
func validateAge(age int) error {
    if age < 0 {
        return &ValidationError{Field: "age", Message: "must be non-negative"}
    }
    return nil
}
```

### Custom types that wrap other errors

Implement `Unwrap()` so `errors.Is` and `errors.As` can traverse the chain:

```go
type QueryError struct {
    Query string
    Err   error
}

func (e *QueryError) Error() string {
    return fmt.Sprintf("query %q: %v", e.Query, e.Err)
}

func (e *QueryError) Unwrap() error {
    return e.Err
}
```

## Error Wrapping with `%w`

Wrapping preserves the original error in a chain that callers can inspect with `errors.Is` and `errors.AsType` (or `errors.As`). Errors SHOULD be wrapped at each layer to build a readable chain.

```go
// ✓ Good -- wraps with context, preserves the chain
func (s *UserService) GetUser(id string) (*User, error) {
    user, err := s.repo.FindByID(id)
    if err != nil {
        return nil, fmt.Errorf("getting user %s: %w", id, err)
    }
    return user, nil
}
```

### `%w` vs `%v`: controlling exposure

Use `%w` within your module to preserve the error chain. Use `%v` at public API / system boundaries to prevent callers from depending on internal error types.

```go
// Internal layer -- wrap to preserve chain
func (r *repo) fetch(id string) error {
    return fmt.Errorf("querying database: %w", err)
}

// Public API boundary -- break chain to hide internals
func (s *PublicService) GetItem(id string) error {
    err := s.repo.fetch(id)
    if err != nil {
        return fmt.Errorf("item unavailable: %v", err) // %v -- callers cannot unwrap
    }
    return nil
}
```

## Inspecting Errors: `errors.Is` and `errors.AsType`

### `errors.Is` -- match against a sentinel value

```go
// ✗ Bad -- direct comparison breaks on wrapped errors
if err == sql.ErrNoRows {

// ✓ Good -- traverses the entire error chain
if errors.Is(err, sql.ErrNoRows) {
    return nil, ErrNotFound
}
```

### `errors.AsType` -- extract a typed error from the chain (Go 1.26+)

[`errors.AsType`](https://pkg.go.dev/errors#AsType) is the generic form of `errors.As`: it returns `(E, bool)` with compile-time type safety, no `reflect`, and no separate `var` + pointer. Prefer it for new code; [`errors.As`](https://pkg.go.dev/errors#As) remains for the same unwrap semantics when you need the older API.

```go
// ✗ Bad -- type assertion breaks on wrapped errors
if ve, ok := err.(*ValidationError); ok {

// ✓ Good -- traverses the entire error chain
if ve, ok := errors.AsType[*ValidationError](err); ok {
    log.Printf("validation failed on field %s: %s", ve.Field, ve.Msg)
}
```

## Combining Errors with `errors.Join`

`errors.Join` (Go 1.20+) combines multiple independent errors into one. The combined error works with `errors.Is` and `errors.AsType` (or `errors.As`) -- each inner error is inspectable.

### Use case: validating multiple fields

```go
func validateUser(u User) error {
    var errs []error

    if u.Name == "" {
        errs = append(errs, errors.New("name is required"))
    }
    if u.Email == "" {
        errs = append(errs, errors.New("email is required"))
    }

    return errors.Join(errs...) // returns nil if errs is empty
}
```

### Use case: parallel operations with independent failures

```go
func closeAll(closers ...io.Closer) error {
    var errs []error
    for _, c := range closers {
        if err := c.Close(); err != nil {
            errs = append(errs, err)
        }
    }
    return errors.Join(errs...)
}
```

### `errors.Is` works through joined errors

```go
err := errors.Join(ErrNotFound, ErrUnauthorized)

errors.Is(err, ErrNotFound)    // true
errors.Is(err, ErrUnauthorized) // true
```

## Panic and Recover

### When to panic

Panic MUST only be used for truly unrecoverable states -- programmer errors, impossible conditions, or corrupt invariants. NEVER use panic for expected failures like network timeouts or missing files.

```go
// ✓ Acceptable -- programmer error in initialization
func MustCompileRegex(pattern string) *regexp.Regexp {
    re, err := regexp.Compile(pattern)
    if err != nil {
        panic(fmt.Sprintf("invalid regex %q: %v", pattern, err))
    }
    return re
}

// ✗ Bad -- panic for a normal failure
func GetUser(id string) *User {
    user, err := db.Find(id)
    if err != nil {
        panic(err) // callers cannot recover gracefully
    }
    return user
}
```
