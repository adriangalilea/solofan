# SoloFan (fork) — working notes

Personal daily-driver fork of [SoloTeamDev/solofan](https://github.com/SoloTeamDev/solofan).
Real fan control on Apple Silicon (M4 Pro, macOS 26.x). Not for release — a tool to
use, mod, and feed clean fixes back upstream.

## Branch model

| Branch | Role | Rule |
|---|---|---|
| `main` | Clean mirror of upstream `origin/main` | **Never commit here.** Sync from upstream; cut PR branches from it. |
| `dev` | Our integration branch = the daily driver | All fork patches + this file. Rebase onto `main` when upstream moves. |
| `fix/*`, `perf/*` | One-concern PR branches | Cut from `main`, cherry-picked from `dev`, target upstream. |

Remotes: `origin` = upstream (SoloTeamDev), `fork` = adriangalilea.

- **Build the daily driver from `dev`.** This file lives only on `dev`, so it never
  leaks into PRs.
- **Sync upstream:** `git fetch origin && git switch main && git merge --ff-only origin/main`,
  then `git switch dev && git rebase main` (resolve, rebuild).
- **New contribution:** `git switch -c fix/x main`, `git cherry-pick <sha from dev>`,
  push to `fork`, open PR against `origin/main`.

## Build / install / measure

```bash
# App (Release, unsigned — local use)
xcodebuild -project fan.xcodeproj -scheme fan -configuration Release \
  -derivedDataPath /tmp/solofan-dd CODE_SIGNING_ALLOWED=NO build

# Privileged helper (hardened flags live in tools/smc-helper/Makefile)
cd tools/smc-helper && make           # -> ./smc-helper, then `make install` copies to fan/Resources/

# Install app  (GOTCHA: `cp -R src /Applications/SoloFan.app` NESTS when the dest
# exists — trash first, then copy, or you get SoloFan.app/SoloFan.app and run a stale build)
osascript -e 'quit app "SoloFan"'; trash /Applications/SoloFan.app
cp -R /tmp/solofan-dd/Build/Products/Release/SoloFan.app /Applications/SoloFan.app
open /Applications/SoloFan.app

# Install the root helper (needs sudo — pbcopy to user; cannot run sudo from here)
sudo install -o root -g wheel -m 755 \
  /Applications/SoloFan.app/Contents/Resources/smc-helper /usr/local/bin/smc-helper

# Measure CPU / energy (instantaneous = 2nd+ sample)
top -l 4 -stats pid,cpu,idlew,power,command -pid $(pgrep -x SoloFan) | grep -i solofan
# Profile a hotspot
sample $(pgrep -x SoloFan) 4 -file /tmp/solo.txt   # look for the real symbols, not __workq_kernreturn/mach_msg2_trap (idle waits)
```

## What's patched (and where it goes)

| Change | Files | Upstream |
|---|---|---|
| Fan control in SYSTEM mode (verify-then-`Ftst` unlock, M4/M5) | `tools/smc-helper/smc.c` | PR #11 |
| Harden helper: bound `fanNum`, clamp RPM, drop `read`/`write`, stack-protector | `tools/smc-helper/smc.c`, `Makefile` | PR #11 |
| Real Apple-silicon die temps (hottest-plausible `Tp`/`Te`/`Tg`) | `SystemMonitor.swift` | PR #12 |
| GPU temp hold across power-gating (no flicker) | `SystemMonitor.swift` | PR #12 |
| Static menu-bar icon (was 20fps redraw) + template tint | `StatusBarManager.swift` | PR #13 |
| Lazy popover content, release on close (was 15-22% idle CPU) | `StatusBarManager.swift`, `SoloFanApp.swift` | PR #13 |
| Fan writes off the main thread (slider freeze) | `FanController.swift`, `FanSpeedView.swift` | PR #14 |

PR status: see `gh pr list --repo SoloTeamDev/solofan --author adriangalilea`.

### Fork-local only (do NOT upstream)
- **Bundled patched helper binary** (`fan/Resources/smc-helper`) — packaging for the
  daily driver; the PRs are source-only.
- **Menu-bar default = icon-only** (`MenuBarDefaults.displayMode = "none"`) — opinionated.

## Fan-control mechanism (proven on this machine)

Full proof + reference-project comparison: `../system-control/docs/FAN-CONTROL.md`.

Short version: fan mode key is `F%dMd` (Intel/M1–M4) or `F%dmd` (M5) — probe it.
Modes `0`=AUTO, `1`=MANUAL, `3`=SYSTEM (`thermalmonitord` actively holding, temperature-
independent — NOT "idle"). To take manual control, write mode `1` and **verify it stuck**
by re-reading; if the firmware silently reclaims it, set `Ftst=1` to suppress
`thermalmonitord`, then retry until it holds. Targets `F%dTg` are 4-byte LE IEEE-754
floats on Apple Silicon.

## Privilege / security model

- Helper installed root:wheel `755` at `/usr/local/bin/smc-helper`; scoped NOPASSWD
  sudoers `%admin ALL=(root) NOPASSWD: /usr/local/bin/smc-helper`.
- Safe here because `/usr/local/bin` is root-owned (Homebrew is `/opt/homebrew` on
  Apple Silicon) and the helper is now **fan-only** (no arbitrary SMC `write`).
- Audit verdict (whole app): no network, telemetry, obfuscation, keychain/pasteboard/
  file access. It is only a fan controller. Login via Apple `SMAppService`.

## TODO

- [ ] Land PRs #11–#14 / address maintainer feedback.
- [ ] Remove dead `tools/smc-write` dev tool (arbitrary SMC writer, unprivileged, unused).
- [ ] `LiquidGlassAmbientBackground` runs a 30fps `TimelineView` — only burns while a
      glass view is visible; find its uses and gate/throttle.
- [ ] Launch-at-login not set — toggle in Settings (SMAppService) if running 24/7.
- [ ] After upstream rebases land, prune merged PR branches.
