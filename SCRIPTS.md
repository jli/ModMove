# Build & Deployment

Use `make` for everything. Building, testing, and log streaming are simple
enough to be inlined directly in the `Makefile`. `run.sh` and `deploy.sh`
remain as separate scripts because they have real logic (killing stale
instances, launching, verifying exactly one instance ends up running) —
`make run`/`make deploy` just make sure a fresh build exists first, then
call them.

## The Two Workflows

| | Command | Where it runs | When to use |
|---|---|---|---|
| **Dev iteration** | `make run` | `./build/ModMove.app` | Testing changes quickly |
| **Canonical install** | `make deploy` | `/Applications/ModMove-jli.app` | "Ship it" — the copy you actually use day-to-day |

The canonical install uses a **stable bundle path** on purpose:

- Accessibility (TCC) permission is granted once and survives redeploys
- Launch-at-login items keep pointing at a valid app
- Launch Services isn't confused by multiple bundles with the same bundle ID

(The old scheme deployed dated copies like `ModMove-jli-v0705-2355.app`. Don't do
that — every new name is a new app to macOS, re-triggering permission prompts and
leaving stale copies and broken login items behind. If you have leftovers:
`rm -rf /Applications/ModMove-jli-*.app`.)

## `make` targets

```bash
make build    # Build to build/ModMove.app - only rebuilds if sources changed
make run      # make build, then kill stale instances and launch from build/
make test     # Run the test suite
make logs     # Stream [ModMove] debug logs (also saved to ./modmove.log)
make deploy   # make build, then install to /Applications/ModMove-jli.app
make clean    # xcodebuild clean + rm -rf build/
make help     # List all targets
```

`make build` is a real Make dependency rule: `build/ModMove.app` depends on
every `.swift`/`.h`/`.m` file plus the `.xcodeproj`, so `make run`/`make deploy`
only invoke `xcodebuild` when something is actually stale — no more remembering
to build before deploying.

### `run.sh` - kill stale instances, launch build/, verify (called by `make run`)

1. Kills **all** running ModMove instances (any bundle name, any location)
2. Launches `./build/ModMove.app`
3. Verifies exactly one instance is running and prints its path

Does **not** touch `/Applications`. Errors out if `./build/ModMove.app`
doesn't exist yet (shouldn't happen via `make run`, since `build` is a
prerequisite).

### `deploy.sh` - kill stale instances, install, launch, verify (called by `make deploy`)

1. Errors out if `./build/ModMove.app` doesn't exist (shouldn't happen via
   `make deploy`, since `build` is a prerequisite)
2. Kills all running instances
3. Replaces `/Applications/ModMove-jli.app` with the build
4. Launches it and verifies exactly one instance is running from the canonical path
5. Warns about stale dated copies from the old scheme

## Killing Instances (Important!)

Multiple simultaneously-running copies cause the "two windows move at once" bug.
Bundle names vary (`ModMove.app`, `ModMove-jli.app`, old dated copies), but the
**binary name is always `ModMove`**, so match on that:

```bash
pkill -x ModMove      # kill ALL copies, wherever they live
pgrep -lx ModMove     # list running copies (should be empty after kill)
ps -p <pid> -o command=   # see which bundle a pid is running from
```

Do **not** grep for `ModMove.app` in the process list — that misses renamed
bundles (this was a real bug in earlier versions of these scripts).

Both `run.sh` and `deploy.sh` do this automatically before launching.

## Manual Testing Checklist

1. `pkill -x ModMove` — kill everything
2. `pgrep -lx ModMove` — confirm nothing is running
3. `make run` — build (if needed) and launch; confirm "✓ Exactly 1 instance running"
4. `make logs` in another terminal
5. Hold ⌃⌥ and move the mouse over a window → window moves, logs show activity
6. Hold ⌃⌥⇧ → window resizes from the closest corner

If gestures do nothing and logs are silent: Accessibility permission is missing
for this copy — System Settings → Privacy & Security → Accessibility.

## Color Coding

`run.sh`/`deploy.sh` use color output for clarity:
- 🔵 **Blue**: Section headers
- 🟡 **Yellow**: Operations in progress
- 🟢 **Green**: Success
- 🔴 **Red**: Errors/warnings
