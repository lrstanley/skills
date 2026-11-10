# Review lenses

Each lens is one read-only reviewer. This file holds the trigger for each
lens, the brief every reviewer gets, and the checklist to paste into it.

## Triggers

| Lens        | Run when                                                                                           | Skip when                                         |
| ----------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| correctness | always                                                                                             | never                                             |
| structure   | the diff adds or moves logic: new functions, types, modules, branches, or a refactor              | trivial tier; docs, config, or tests only         |
| cleanup     | the diff adds or edits code of any real size                                                       | trivial tier; docs or config only                 |
| performance | hot paths, loops over data, I/O, queries, rendering, caching, allocation-heavy or concurrent code | the change is not on a path where cost can matter |

Turn on the **security checklist** inside the correctness reviewer when the
diff touches a trust boundary: auth, sessions, permissions, roles, tokens,
secrets, crypto, user or network input parsing, deserialization, file paths,
shell or process exec, SQL or other query building, templating or HTML
output, redirects, CORS and security headers, uploads, webhooks, or
dependency changes. Any of these also puts the change in the risky tier.

Also treat as risky: migrations or deletes that can lose data, and shared
state, locking, goroutines, threads, async ordering, retries, or caches that
can serve stale data.

## Brief

Fill in the placeholders and append the checklist for the lens. Every
reviewer of a round gets the same header, so their findings line up.

```
Review only. Leave every file unchanged: no edits, formatters, commits,
pushes, PR comments, subagents, or other reviewers.
Repo: <abs path>  Base: <sha>  Lens: <lens>
Intent: <1-2 sentences>  Out of scope: <scope>
Checks: <commands run and results, missing or pre-failing checks>
Diff: git diff <base> [-- <paths>]; git status --short (read untracked files).
Read the surrounding code and callers you need. Report only problems in the
diff or caused by it. A problem that predates the diff is a nit marked
"pre-existing".
<lens checklist>
Severity:
  blocker = the intended case is wrong, or data loss, or a security hole.
  should  = <lens-specific should, from the checklist>.
  nit     = everything else.
Prefer a few high-conviction findings over a long list. Give the smallest
fix: delete or narrow beats adding guards, options, or layers.
Reply with only:
VERDICT: APPROVE or CHANGES
<P><n> [blocker|should|nit] <file>:<line> <claim>. Evidence: <why>. Fix: <smallest fix>
```

`<P>` is the lens prefix, so ids stay stable and unique across lenses and
rounds: `C` correctness (and security), `S` structure, `K` cleanup, `P`
performance. The on-demand tests tier uses `T` and has its own brief and
checklist in [tests-tier.md](tests-tier.md); it is never mixed with these lenses.

For a later round, add after the header:

```
Round <n>. Review only the changed hunks below and the open ids.
Ledger:
  fixed: <id> <what changed>
  disagree: <id> <evidence>
  declined: <id> <reason>
Changed since last round: <files and hunks>
Mark each open id from your lens "resolved" or "still open: <reason>".
Raise new findings only in the changed hunks.
```

## Correctness

Find bugs, broken callers, and mismatches with the stated intent.

- Logic errors in the intended case: wrong condition, off-by-one, inverted
  check, wrong default, missed return.
- Callers and implementers the diff breaks: changed signatures, changed
  return values or errors, changed ordering or side effects, interfaces no
  longer satisfied.
- Error handling that drops, swallows, or misreports an error the caller
  needs.
- Resource handling: leaks, missing close or cancel, unbounded growth or
  loops.
- State and concurrency: races, lock ordering, shared mutable state, async
  ordering, retries that double-apply, caches that serve stale data,
  half-applied updates.
- Tests that pass without exercising the change, or that assert the wrong
  behavior.
- Claims in comments, docs, or names that the code does not do.

Skip style unless it hides a bug. Rare paths, extra compatibility, and
speculative inputs the intent does not need are nits.

**should**: a real bug that callers will hit within the intent.

### Security checklist

Append when the security trigger fires. Check only what the diff touches.

- Authn and authz: every new entry point checks identity and permission on
  the server side; no check relies on client-supplied role or ownership
  fields; object access checks ownership, not only login.
- Input: untrusted input is validated or parsed at the boundary before it
  reaches queries, shell, file paths, templates, redirects, or
  deserializers. Look for injection, path traversal, SSRF, open redirects,
  and unescaped output.
- Secrets: nothing secret is logged, returned in errors, committed, or sent
  to the client. Tokens are compared in constant time where it matters.
- Crypto and sessions: standard library primitives, no homemade schemes,
  sensible expiry and rotation, secure cookie flags.
- Failure mode: errors fail closed, not open. Limits exist on sizes, counts,
  and rates where a caller can exhaust resources.
- Dependencies: new or bumped packages are expected, maintained, and pinned.

A reachable exploit is a blocker. A missing defense with a plausible path is
a should. Hardening with no path is a nit.

## Structure

Find the restructuring that makes the change simpler, smaller, and more
direct with the same behavior. Look first for a **code judo** move: a
reframing that makes whole branches, helpers, modes, flags, or layers
disappear instead of moving them around.

Work from **first principles**: ask how the code would look if it had been
designed knowing today's requirements from the start. Treat each special
case the diff adds (an `if` for one value, a parameter for one caller, a
swallowed error, a retry or sleep, a skipped test) as a requirement the
design never accounted for. Look for the one fix behind several problems,
which often looks nothing like them, and report it as one finding that lists
the problems it removes. Test every proposed shape the same way: pieces that
change together end up together, pieces that change for different reasons
are not tied, and everything depends on what changes less.

- Ad-hoc conditionals, special cases, or one-off flags bolted onto an
  unrelated or already busy flow.
- Feature logic leaking into shared code, or logic in the wrong layer,
  package, or module when a canonical home exists.
- Thin wrappers, identity abstractions, or pass-through helpers that add
  indirection without clarity.
- Generic or "magic" mechanisms that hide a simple data shape.
- Type boundaries muddied by casts, `any`, `unknown`, optional parameters,
  or ad-hoc object shapes where an explicit type would simplify control
  flow.
- Repeated conditionals that point at a missing model, dispatcher, or state
  machine.
- Refactors that move complexity without reducing the concepts a reader has
  to hold.
- A file pushed from under 1000 lines to over 1000 lines by this change.
  Propose the split.
- Independent work serialized for no reason, or related updates that can be
  left half-applied, when the cleaner structure is obvious.
- Reuse: a bespoke helper, type, or pattern that duplicates one already in
  the codebase or elsewhere in the diff. Name the existing one by path.

Search the codebase for existing helpers before proposing a new one. Rename
or formatting suggestions are nits.

**should**: a concrete restructuring that deletes complexity the diff adds,
or a clear duplicate of an existing helper, or logic in the wrong layer.
Describe the target shape in 1-3 lines.

## Cleanup

Find local simplifications in the changed code.

- Comments that restate the code instead of explaining intent, invariants,
  or edge cases.
- Helpers used once that read better inlined.
- Nullable or optional values that force defensive checks and blur the real
  invariant.
- Catch-all error handling that swallows errors without saying which ones
  are expected.
- Abstraction, config objects, or interfaces added before there is a second
  user.
- Avoidable casts, non-null assertions, or overly broad types.
- Stored state that can be derived from other state.
- Dead code: unused branches, parameters, fallbacks, or compatibility paths
  kept without evidence they are needed.

**should**: a simplification that removes code or a moving part from the
diff and makes the flow clearly easier to follow. Everything cosmetic is a
nit.

## Performance

Find costs that matter on paths where performance matters. Name the path and
why it is hot; a cost on a cold path is a nit.

- Blocking or synchronous work on an event loop, UI thread, or request path.
- N+1 I/O: per-item queries, network, filesystem, or RPC calls that can be
  batched.
- Repeated expensive work (parsing, compiling, lookups, allocation) that can
  be computed once or cached safely.
- Quadratic behavior: nested scans, repeated string or slice concatenation in
  loops, linear lookups inside loops.
- Busy waits or tight polling instead of events, timers, or backoff.
- Unbounded buffers, queues, goroutines, or caches.
- Chatty logging or telemetry inside tight loops.

Include a benchmark, measurement, or complexity argument when you have one.

**should**: a cost on a hot path that scales with input or is clearly
measurable. Micro-optimizations are nits.
