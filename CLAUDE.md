# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A single-file bash script (`daily-update.sh`) that automates daily macOS maintenance — updating Homebrew, npm, pip3, Ruby gems, Mac App Store apps, VS Code, and system software. Designed to run unattended via launchd or cron.

## Running

```bash
./daily-update.sh            # Run all updates
./daily-update.sh --dry-run  # Preview without making changes
```

There is no build step, test suite, or linter. This is a standalone bash script.

## Architecture

**`daily-update.sh`** uses `set -euo pipefail` and runs 9 update sections sequentially:
1. macOS Software Updates (flags only, no auto-install)
2. Mac App Store via `mas`
3. Homebrew formulae
4. Homebrew casks
5. Homebrew cleanup + `brew doctor`
6. npm global packages (includes MCP filesystem server)
7. pip3 core tools
8. Ruby gems (update system, update gems, cleanup old versions)
9. VS Code + extensions

**Key design patterns:**
- **Fail-soft execution** — individual step failures are logged with `✗` but don't halt the script. The `run_step()` helper wraps `eval` with error capture and continues on failure.
- **Platform detection** — auto-detects Apple Silicon (`/opt/homebrew`) vs Intel (`/usr/local`) Homebrew paths.
- **Graceful degradation** — tools not found (npm, pip3, gem, VS Code, mas) are skipped with a log message.
- **Dry-run mode** — `--dry-run` flag causes `run_step()` to log commands without executing them.
- **Logging** — all output goes to `~/.local/log/daily-update-YYYY-MM-DD.log` via the `log()` helper (tee to stdout + file). A summary section is built with `add_summary()` and printed at the end.

**`com.craigfletcher.daily-update.plist`** is a macOS LaunchAgent config that schedules the script to run daily at 6 AM.

## Shell Conventions

- Use `log()` for all user-facing output (not raw `echo`)
- Use `section()` for new update categories
- Use `run_step "description" "command"` to wrap commands with error handling and dry-run support
- Use `add_summary()` to register results for the end-of-run summary
- Check tool availability with `command -v` before use
