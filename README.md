# apptraf

Lightweight per-application network traffic tracker for macOS.
Hourly buckets, 7-day retention, native AppKit UI. No frameworks, no Electron, no telemetry.

- **Daemon** (`apptrafd`) samples `nettop` once per minute, accounts byte deltas per
  process, writes to a local SQLite file. Idle footprint: ~3 MB RSS, ~0% CPU.
- **UI** (`apptraf`) opens a window with a period selector
  (1h / 6h / 24h / 7d), a bar chart of the top 10 apps and a sortable table.
- **Self-healing**: installed as a Homebrew background service with
  `KeepAlive=true` — launchd restarts the daemon if it dies.

Data lives at `~/Library/Application Support/AppTraf/data.sqlite`.

## Install

```sh
brew tap hexstyle/apptraf https://github.com/hexstyle/apptraf
brew install hexstyle/apptraf/apptraf
brew services start hexstyle/apptraf/apptraf
```

Homebrew 6+ requires trusting third-party taps. If `brew install` rejects
the tap, run `brew trust --formula hexstyle/apptraf/apptraf` once, or set
`HOMEBREW_NO_REQUIRE_TAP_TRUST=1`.

Requires Xcode Command Line Tools (provides `swift`). If they're missing
the installer will prompt you to install them.

Open the UI:

```sh
apptraf
```

The daemon needs ~2 minutes after first start to establish per-process
baselines — the first sample is a baseline, traffic is recorded from the
second sample onward.

## Update

```sh
brew update && brew upgrade apptraf
brew services restart apptraf
```

## Uninstall

```sh
brew services stop apptraf
brew uninstall apptraf
brew untap hexstyle/apptraf
rm -rf ~/Library/Application\ Support/AppTraf
```

## How it works

`nettop -P -L 1 -J bytes_in,bytes_out -x` gives cumulative byte counters
per process. The daemon keeps a `process_state` row per (pid, app) and
computes `delta = current - last_seen` on every sample. Deltas are added
to the current hour's bucket in the `samples` table. State rows older
than 5 minutes are evicted (process assumed gone). Sample rows older
than 7 days are purged.

Process names come from `nettop`, which truncates them to 15 characters.
Multiple processes of the same app (e.g. Chrome helpers) aggregate under
the same truncated name.

## Permissions

`apptrafd` runs as a user-level LaunchAgent, so it sees the user's own
processes plus whatever `nettop` exposes without root. That covers
essentially every GUI app and most background services. System-level
daemons running as root may be partially missing — this is intentional,
the agent does not request elevated privileges.

## Building from source

```sh
swift build -c release
.build/release/apptrafd   # foreground run, Ctrl-C to stop
.build/release/apptraf    # opens the UI
```

Requires Xcode 14+ command line tools.

## License

MIT — see [LICENSE](LICENSE).
