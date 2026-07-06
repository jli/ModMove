# Build & Deployment Scripts

Quick reference for ModMove build and deployment scripts.

## The Two Workflows

| | Command | Where it runs | When to use |
|---|---|---|---|
| **Dev iteration** | `./run.sh` | `./build/ModMove.app` | Testing changes quickly |
| **Canonical install** | `./deploy.sh` | `/Applications/ModMove-jli.app` | "Ship it" — the copy you actually use day-to-day |

The canonical install uses a **stable bundle path** on purpose:

- Accessibility (TCC) permission is granted once and survives redeploys
- Launch-at-login items keep pointing at a valid app
- Launch Services isn't confused by multiple bundles with the same bundle ID

(The old scheme deployed dated copies like `ModMove-jli-v0705-2355.app`. Don't do
that — every new name is a new app to macOS, re-triggering permission prompts and
leaving stale copies and broken login items behind. If you have leftovers:
`rm -rf /Applications/ModMove-jli-*.app`.)

## Scripts

### `run.sh` - Build and run from build/ (dev iteration)

```bash
./run.sh
```

1. Builds Release configuration to `./build/ModMove.app`
2. Kills **all** running ModMove instances (any bundle name, any location)
3. Launches from `./build/`
4. Verifies exactly one instance is running and prints its path

Does **not** touch `/Applications`.

### `deploy.sh` - Install the canonical copy

```bash
./deploy.sh
```

1. Requires an existing build (`./build.sh` or `./run.sh` first)
2. Kills all running instances
3. Replaces `/Applications/ModMove-jli.app` with the build
4. Launches it and verifies exactly one instance is running from the canonical path
5. Warns about stale dated copies from the old scheme

### `build.sh` - Build only

```bash
./build.sh
```

Builds Release configuration to `./build/ModMove.app` without launching anything.

### `logs.sh` - Stream debug logs

```bash
./logs.sh
```

Streams `[ModMove]` log output (also saved to `./modmove.log`). Trigger a
move/resize gesture and you should see `Got window - app: ...` lines.

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
3. `./run.sh` — build and launch; confirm "✓ Exactly 1 instance running"
4. `./logs.sh` in another terminal
5. Hold ⌃⌥ and move the mouse over a window → window moves, logs show activity
6. Hold ⌃⌥⇧ → window resizes from the closest corner

If gestures do nothing and logs are silent: Accessibility permission is missing
for this copy — System Settings → Privacy & Security → Accessibility.

## Color Coding

Scripts use color output for clarity:
- 🔵 **Blue**: Section headers
- 🟡 **Yellow**: Operations in progress
- 🟢 **Green**: Success
- 🔴 **Red**: Errors/warnings
