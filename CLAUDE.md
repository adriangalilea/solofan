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
- **One commit = one audience.** Fork-local changes (this file, the icon-only default,
  the bundled helper binary) go in their OWN commits, never mixed with upstreamable
  code — otherwise a cherry-pick drags them into the PR.

**Sync upstream when `origin/main` moves:**
```bash
git fetch origin
git switch main && git merge --ff-only origin/main && git push fork main
git switch dev && git rebase main          # resolve conflicts, then rebuild
```

**Open a PR from a `dev` commit** (branch off the clean mirror, cherry-pick code-only commit):
```bash
git switch -c fix/x main                   # NOT off dev — main has no CLAUDE.md
git cherry-pick <sha>                      # a code-only commit from dev
git push -u fork fix/x
gh pr create --repo SoloTeamDev/solofan --base main --head adriangalilea:fix/x
```
The branch starts from `main` (no `CLAUDE.md`) and you cherry-pick only the code commit,
so nothing fork-local can leak into the PR. Add later commits to an open PR by
cherry-picking onto the same branch and `git push fork fix/x`.

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
| Auto/manual speed pref no longer clobbered by volatile `F#Mx` (forgot its value) | `FanController.swift` | PR #15 |

PR status: see `gh pr list --repo SoloTeamDev/solofan --author adriangalilea`.

### Fork-local only (do NOT upstream)
- **Bundled patched helper binary** (`fan/Resources/smc-helper`) — packaging for the
  daily driver; the PRs are source-only.
- **Menu-bar default = icon-only** (`MenuBarDefaults.displayMode = "none"`) — opinionated.
- **250 RPM slider steps** (`DashboardWidgetViews.swift`, `FanSpeedView.swift`, was 100) —
  opinionated UX; fewer detents feel better. Kept local.

### Launch at login
Already implemented — `LaunchAtLoginManager` (modern `SMAppService.mainApp`), toggle in
Settings. NOT enabled by default. Enable it from inside the app (⌘, → Settings → Launch
at Login) so it registers the **current** bundle — only meaningful once the app lives in
`/Applications` (a transient build path would register garbage). macOS may require
approval under System Settings → Login Items for an unsigned build.

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

- [ ] Land PRs #11–#15 / address maintainer feedback.
- [ ] Remove dead `tools/smc-write` dev tool (arbitrary SMC writer, unprivileged, unused).
- [x] 30fps `TimelineView`s (`LiquidGlassAmbientBackground`, `DashboardJiggleModifier`):
      both were dead code (never instantiated/applied) — deleted, along with the unused
      `LiquidGlassPanel`. Nothing referenced them; the live `liquidGlass()` modifier stays.
- [x] Launch at login exists (`SMAppService`); see the section above. Enable via ⌘, once.
- [ ] After upstream rebases land, prune merged PR branches.
