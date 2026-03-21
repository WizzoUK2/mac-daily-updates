# Mac Daily Updates

A shell script that automates daily maintenance on macOS — keeping Homebrew, npm, pip3, Ruby gems, Mac App Store apps, VS Code, and system tools up to date.

## What it does

1. **macOS** — checks for system software updates (flags but doesn't auto-install)
2. **Mac App Store** — updates apps via `mas` (installs `mas` if missing)
3. **Homebrew formulae** — updates and upgrades all installed packages
4. **Homebrew casks** — upgrades GUI apps (Chrome, Docker, Slack, etc.)
5. **Homebrew cleanup** — removes old versions and runs `brew doctor`
6. **npm global packages** — updates all global packages + MCP filesystem server
7. **pip3** — upgrades core tools (pip, setuptools, wheel) and reports outdated packages
8. **Ruby Gems** — updates RubyGems system, upgrades installed gems, and cleans up old versions
9. **VS Code** — checks for updates and refreshes all extensions

## Usage

```bash
# Run all updates
./daily-update.sh

# Preview what would happen (no changes)
./daily-update.sh --dry-run
```

## Installation

```bash
git clone https://github.com/WizzoUK2/mac-daily-updates.git
cd mac-daily-updates
chmod +x daily-update.sh
```

## Scheduling (cron)

Run daily at 6 AM:

```bash
crontab -e
```

Add:

```
0 6 * * * /path/to/mac-daily-updates/daily-update.sh >> /dev/null 2>&1
```

## Scheduling (launchd)

Copy the included plist to your LaunchAgents:

```bash
cp com.craigfletcher.daily-update.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.craigfletcher.daily-update.plist
```

## Logs

Logs are written to `~/.local/log/daily-update-YYYY-MM-DD.log`.

## Requirements

- macOS 12+
- [Homebrew](https://brew.sh)
- Node.js / npm (for global package updates)
- Python 3 / pip3
- Ruby / gem (for gem updates)
- [mas](https://github.com/mas-cli/mas) (auto-installed if missing)
