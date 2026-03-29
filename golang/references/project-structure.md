# Project Structure and Module Management

## Standard Project Layout

```
myproject/
├── .github
│   ├── Dockerfile
│   └── [...]
├── .gitignore
├── .golangci.yaml        # Linting configuration
├── .vscode
│   └── [...]             # VS Code settings, launch.json, recommended extensions, etc.
├── cmd/                  # Multi-command applications
│   ├── server/
│   │   └── main.go       # Entry point for server
│   └── cli/
│       └── main.go       # Entry point for CLI tool
├── internal/             # Private application code
│   ├── api/              # API handlers
│   ├── models/           # Generic models
│   ├── service/          # Business logic
│   └── repository/       # Data access layer
├── pkg/                  # Public/external library code (when writing an application, not a library)
│   └── models/           # Shared models
├── web/                  # Web assets
│   ├── [...]
├── go.mod               # Module definition
├── go.sum               # Dependency checksums
├── Makefile             # Build automation (when using Make)
├── Taskfile.yaml        # Build automation (when using Task)
├── main.go              # Entry point for simple, single-command applications
├── LICENSE              # License
└── README.md
```

## go.mod Basics

```go
// Initialize module
// go mod init github.com/user/project

module github.com/user/myproject

go 1.26

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
    go.uber.org/zap v1.26.0
)

require (
    // Indirect dependencies (automatically managed)
    github.com/bytedance/sonic v1.9.1 // indirect
    github.com/chenzhuoyu/base64x v0.0.0-20221115062448-fe3a3abad311 // indirect
)

// Replace directive for local development
replace github.com/user/mylib => ../mylib

// Retract directive to mark bad versions
retract v1.0.1 // Contains critical bug
```

## Module Commands

```bash
# Initialize module
go mod init github.com/user/project

# Add missing dependencies
go mod tidy

# Download dependencies
go mod download

# Verify dependencies
go mod verify

# Show module graph
go mod graph

# Show why package is needed
go mod why github.com/user/package

# Vendor dependencies (copy to vendor/)
go mod vendor

# Update dependency
go get -u github.com/user/package

# Update to specific version
go get github.com/user/package@v1.2.3

# Update all dependencies
go get -u ./...

# Remove unused dependencies
go mod tidy
```

## Internal Packages

```go
// internal/ packages can only be imported by code in the parent tree

myproject/
├── internal/
│   ├── auth/           # Can only be imported by myproject
│   │   └── jwt.go
│   └── database/
│       └── postgres.go
└── pkg/
    └── models/         # Can be imported by anyone
        └── user.go

// This works (same project):
import "github.com/user/myproject/internal/auth"

// This fails (different project):
import "github.com/other/project/internal/auth" // Error!

// Internal subdirectories
myproject/
└── api/
    └── internal/       # Can only be imported by code in api/
        └── helpers.go
```

## Package Organization

```go
// user/user.go - Domain package
package user

import (
    "context"
    "time"
)

// User represents a user entity
type User struct {
    ID        string
    Email     string
    CreatedAt time.Time
}

// Repository defines data access interface
type Repository interface {
    Create(ctx context.Context, user *User) error
    GetByID(ctx context.Context, id string) (*User, error)
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
}

// Service handles business logic
type Service struct {
    repo Repository
}

// NewService creates a new user service
func NewService(repo Repository) *Service {
    return &Service{repo: repo}
}

func (s *Service) RegisterUser(ctx context.Context, email string) (*User, error) {
    user := &User{
        ID:        generateID(),
        Email:     email,
        CreatedAt: time.Now(),
    }
    return user, s.repo.Create(ctx, user)
}
```

## Multi-Module Repository (Monorepo)

```
monorepo/
├── go.work              # Workspace file
├── services/
│   ├── api/
│   │   ├── go.mod
│   │   └── main.go
│   └── worker/
│       ├── go.mod
│       └── main.go
└── shared/
    └── models/
        ├── go.mod
        └── user.go

// go.work
go 1.26

use (
    ./services/api
    ./services/worker
    ./shared/models
)

// Commands:
// go work init ./services/api ./services/worker
// go work use ./shared/models
// go work sync
```

## Build Tags and Constraints

```go
// +build integration
// integration_test.go

package myapp

import "testing"

func TestIntegration(t *testing.T) {
    // Integration test code
}

// Build: go test -tags=integration

// File-level build constraints (Go 1.17+)
//go:build linux && amd64

package myapp

// Multiple constraints
//go:build linux || darwin
//go:build amd64

// Negation
//go:build !windows

// Common tags:
// linux, darwin, windows, freebsd
// amd64, arm64, 386, arm
// cgo, !cgo
```

## Makefile Example

Don't leave inline comments, they're for reference only.

```makefile
.DEFAULT_GOAL := build

export PROJECT := "myproject"
export PACKAGE := "github.com/user/myproject"

license: # only for projects which are already licensed by Liam Stanley
    curl -sL https://liam.sh/-/gh/g/license-header.sh | bash -s

clean: # usually only needed for applications, not libraries
    /bin/rm -rfv ${PROJECT}

fetch:
    go mod tidy

up:
    go get -u ./...
    go get -u -t ./...
    go mod tidy

prepare: clean fetch
    go generate -x ./...
    go run . generate-markdown > USAGE.md # clix/v2 specific pattern

dlv: prepare
    dlv debug \
        --headless --listen=:2345 \
        --api-version=2 --log \
        --allow-non-terminal-interactive \
        ${PACKAGE} -- \
        --debug

debug: prepare
    rm -rf ./tmp
    go run ${PACKAGE} \
        --debug

build: prepare
    CGO_ENABLED=0 \
    go build \
        -ldflags '-d -s -w -extldflags=-static' \
        -tags=netgo,osusergo,static_build \
        -installsuffix netgo \
        -trimpath \
        -o ${PROJECT} \
        ${PACKAGE}
```

## Taskfile Example

[Full Reference](https://taskfile.dev/llms.txt). Don't leave inline comments, they're for reference only.

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: "3"
vars:
  PROJECT: "myproject"
  PACKAGE: "github.com/user/myproject"
env:
  CGO_ENABLED: 0
  GOEXPERIMENT: jsonv2,greenteagc # optional experimental Go features

dotenv: [".env"]
method: timestamp
tasks:
  default: # build for applications, test/lint for libraries
    desc: build the project
    cmds:
      - task: build
  license: # only for projects which are already licensed by Liam Stanley
    desc: generate license headers
    cmds:
      - curl -sL https://liam.sh/-/gh/g/license-header.sh | bash -s
  clean: # usually only needed for applications, not libraries
    desc: clean build artifacts
    cmds:
      - rm -rfv {{.PROJECT}}
  fetch:
    desc: tidy go modules
    aliases: [tidy, download]
    cmds:
      - go mod tidy
  up:
    desc: update dependencies
    aliases: [update, upgrade]
    cmds:
      - go get -u ./...
      - go get -u -t ./...
      - task: fetch
  prepare:
    desc: prepare build environment
    deps: [fetch]
    aliases: [init, generate, gen]
    sources: [] # file patterns which result in other files being changed
    generates: [] # file patterns which are generated by the sources changing
    cmds:
      - go generate -x ./...
  test:
    desc: run tests
    deps: [prepare]
    cmds:
      - go test -v -race -count 5 -p 3 {{ or .CLI_ARGS "./..." }}
  lint:
    desc: run linter
    deps: [prepare]
    cmds:
      - go run golang.org/x/tools/go/analysis/passes/modernize/cmd/modernize@latest -fix ./...
      - golangci-lint run --fix
  fmt:
    desc: format code
    deps: [prepare]
    aliases: [format]
    cmds:
      - gofumpt -w .
  # generally only needed for applications which may spin up their own pprof server. e.g.:
  #   import _ "net/http/pprof" //nolint:gosec
  #
  #   if cli.Flags.EnablePprof {
  #       go func() {
  #           slog.InfoContext(ctx, "pprof server starting on http://localhost:6060")
  #           err := http.ListenAndServe("localhost:6060", nil) //nolint:gosec
  #           if err != nil {
  #               slog.Error("failed to start pprof server", "error", err)
  #           }
  #       }()
  #   }
  profile:cpu: go tool pprof -http :6061 'http://127.0.0.1:6060/debug/pprof/profile?seconds=15'
  profile:heap: go tool pprof -http :6061 'http://127.0.0.1:6060/debug/pprof/heap'
  profile:allocs: go tool pprof -http :6061 'http://127.0.0.1:6060/debug/pprof/allocs'
  dlv:
    desc: run with delve debugger
    deps: [prepare]
    aliases: [delve, debugger]
    cmds:
      - |
        dlv debug \
          --headless \
          --listen=:2345 \
          --api-version=2 \
          --log \
          --allow-non-terminal-interactive \
          {{.PACKAGE}} -- --debug {{.CLI_ARGS}}
  debug: # usually only needed for applications, not libraries
    desc: run in debug mode
    deps: [prepare]
    aliases: [dev, run]
    interactive: true # for interactive apps
    cmds:
      - |
        go run {{.PACKAGE}} \
          --debug \
          {{.CLI_ARGS}}
  build: # usually only needed for applications, not libraries
    desc: build the application
    deps: [prepare]
    cmds:
      - |
        go build \
          -ldflags '-d -s -w -extldflags=-static' \
          -tags=netgo,osusergo,static_build \
          -installsuffix netgo \
          -trimpath \
          -o {{.PROJECT}} {{.PACKAGE}}
```

## Dockerfile Multi-Stage Build

```dockerfile
FROM golang:latest as build
WORKDIR /build

COPY . /build/
WORKDIR /build
RUN \
    --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/go \
    make build

FROM alpine:3.23
RUN apk add --no-cache ca-certificates
COPY --from=build /build/myproject /usr/local/bin/myproject

WORKDIR /
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
CMD ["/usr/local/bin/myproject"]
```

## Go Generate

```go
// models/user.go
//go:generate mockgen -source=user.go -destination=../mocks/user_mock.go -package=mocks

package models

type UserRepository interface {
    GetUser(id string) (*User, error)
    SaveUser(user *User) error
}

// tools.go - Track tool dependencies
//go:build tools

package tools

import (
    _ "github.com/golang/mock/mockgen"
    _ "golang.org/x/tools/cmd/stringer"
)

// Install tools:
// go install github.com/golang/mock/mockgen@latest

// Run generate:
// go generate ./...
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `go mod init` | Initialize module |
| `go mod tidy` | Add/remove dependencies |
| `go mod download` | Download dependencies |
| `go get package@version` | Add/update dependency |
| `go generate ./...` | Run code generation |
| `go work init` | Initialize workspace |
