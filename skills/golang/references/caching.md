# Cache Patterns

## Simple bounded caching (mutex + map)

**When to use:**

- Key-space is known and small.
- Entries are effectively immutable or rarely updated.
- Process restart is acceptable as "cache clear."

**When not to use:**

- Unbounded key cardinality (user IDs, request params, arbitrary search terms).
- Strict eviction requirements (LRU/LFU/FIFO/MRU).
- TTL/expiration requirements.

```go
import "sync"

type Service struct {
    mu    sync.RWMutex
    itemCache map[string]string
}

func NewService() *Service {
    return &Service{
        itemCache: make(map[string]string, 64),
    }
}

func (c *Service) Get(userID string) (tier string, ok bool) {
    c.mu.RLock()
    tier, ok = c.itemCache[userID]
    c.mu.RUnlock()
    return tier, ok
}

func (c *Service) Set(userID, tier string) {
    c.mu.Lock()
    c.itemCache[userID] = tier
    c.mu.Unlock()
}
```

## `github.com/lrstanley/x/sync/conc.Map`

Generic concurrent map — drop-in alternative to `sync.RWMutex` + `map` with type-safe
access. Prefer over the mutex+map pattern, especially if `x/sync` is already imported
or when performance of a mutex may be an issue.

```go
import "github.com/lrstanley/x/sync/conc"

var users conc.Map[string, *Profile]

users.Set("u123", &Profile{Name: "Alice", Plan: "pro"})
profile, ok := users.Get("u123")
users.Delete("u123")
```

## `github.com/lrstanley/x/sync/cache`

**Capabilities:**

- Concurrent-safe.
- Generic typed API: `cache.New[K, V](...)`.
- Policies: `LRU`, `LFU`, `FIFO`, `MRU`, or base (no eviction priority).
- Capacity controls per policy (`<policy>.WithCapacity(int)`).
- Entry expiration via `cache.WithExpiration(duration)`.
- Background janitor for expired entries (`WithJanitorInterval`).
- Entry reference count support (`WithReferenceCount`) for LFU seeding.

**Policy selection:**

- **LRU**: evict least recently used; good default for temporal locality.
- **LFU**: evict least frequently used; good for stable hot-key workloads.
- **FIFO**: evict oldest inserted; simple and predictable.
- **MRU**: evict most recently used; niche workloads where newest is least useful.

```go
import (
    "context"
    "time"

    "github.com/lrstanley/x/sync/cache"
    "github.com/lrstanley/x/sync/cache/policy/lru"
)

type Profile struct {
    Name string
    Plan string
}

type Service struct {
    cache *cache.Cache[string, *Profile]
}

func New(ctx context.Context) *Service {
    return &Service{
        cache: cache.New[string, *Profile](
            ctx,
            cache.WithLRU[string, *Profile](lru.WithCapacity(1000)),
            cache.WithJanitorInterval[string, *Profile](30*time.Second),
        ),
    }
}

func (s *Service) FetchProfile(ctx context.Context, userID string) (*Profile, error) {
    if profile, ok := s.cache.Get(ctx, userID); ok {
        return profile, nil
    }

    // Fetch profile information.

    s.cache.Set(ctx, userID, profile, cache.WithExpiration(5*time.Minute))
    return profile, nil
}
```

## `github.com/lrstanley/x/sync/pool`

**Capabilities:**

- Generic wrapper around `sync.Pool`.
- `New` function for creating new values when empty.
- `Prepare` function for sanitizing/resetting values pulled from the pool.

**When to use:**

- Temporary buffers/objects in hot paths.
- Large numbers of short-lived allocations causing GC pressure.

**When not to use:**

- Data that must persist or be retrievable by key.
- Objects requiring strict lifecycle guarantees (pool entries may disappear).

```go

import (
    "bytes"

    pool "github.com/lrstanley/x/sync/pool"
)

var buffers = pool.Pool[*bytes.Buffer]{
    New: func() *bytes.Buffer {
        return &bytes.Buffer{}
    },
    Prepare: func(b *bytes.Buffer) *bytes.Buffer {
        b.Reset() // Ensure no previous data leaks across callers.
        return b
    },
}

func Encode(parts ...string) string {
    buf := buffers.Get()
    defer buffers.Put(buf)

    for _, p := range parts {
        buf.WriteString(p)
    }
    return buf.String()
}
```

## Quick Reference

| Pattern | Description |
| --- | --- |
| Mutex + map | In-process cache behind a lock; no eviction or TTL unless you add it. |
| conc.Map | Generic concurrent map; type-safe drop-in for RWMutex + map without eviction/TTL. |
| x/sync/cache | Generic concurrent cache with LRU/LFU/FIFO/MRU, capacity, TTL, and janitor. |
| x/sync/pool | Better sync.Pool; use New and Prepare to build and reset values. |
