#!/bin/bash
#
# daily-update.sh — Daily macOS maintenance script
# Keeps Homebrew, npm, pip3, Ruby gems, Mac App Store, VS Code, and system tools up to date.
#
# Usage:
#   ./daily-update.sh          # Run all updates
#   ./daily-update.sh --dry-run # Show what would be updated without making changes
#
# Recommended: run via launchd or cron at 6 AM daily
#   crontab -e → 0 6 * * * /path/to/daily-update.sh >> /path/to/daily-update.log 2>&1
#

set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/daily-update-$(date +%Y-%m-%d).log"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ─── Helpers ────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

section() {
    log ""
    log "═══════════════════════════════════════════════════════"
    log "  $1"
    log "═══════════════════════════════════════════════════════"
}

run_step() {
    local description="$1"
    shift
    log "→ $description"
    if $DRY_RUN; then
        log "  [dry-run] Would execute: $*"
        return 0
    fi
    if "$@" >> "$LOG_FILE" 2>&1; then
        log "  ✓ Done"
    else
        log "  ✗ Failed (exit code $?) — continuing..."
    fi
}

run_step_eval() {
    local description="$1"
    shift
    log "→ $description"
    if $DRY_RUN; then
        log "  [dry-run] Would execute: $*"
        return 0
    fi
    if eval "$@" >> "$LOG_FILE" 2>&1; then
        log "  ✓ Done"
    else
        log "  ✗ Failed (exit code $?) — continuing..."
    fi
}

# Ensure Homebrew is in PATH (Apple Silicon vs Intel)
if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Ensure pyenv shims are in PATH (ahead of Homebrew)
if [[ -d "${HOME}/.pyenv" ]]; then
    export PYENV_ROOT="${HOME}/.pyenv"
    export PATH="${PYENV_ROOT}/shims:${PATH}"
fi

# Ensure npm global bin is in PATH
if [[ -d "${HOME}/.npm-global/bin" ]]; then
    export PATH="${HOME}/.npm-global/bin:${PATH}"
fi

# Use user-writable gem directory instead of system /Library/Ruby/Gems
if command -v ruby &>/dev/null; then
    export GEM_HOME="${HOME}/.gem/ruby/$(ruby -e 'puts RbConfig::CONFIG["ruby_version"]')"
    export PATH="${GEM_HOME}/bin:${PATH}"
fi

# ─── Start ──────────────────────────────────────────────────────
log "Daily macOS update started"
log "Hostname: $(hostname)"
log "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
if $DRY_RUN; then
    log "*** DRY RUN MODE — no changes will be made ***"
fi

SUMMARY=""
add_summary() {
    SUMMARY="${SUMMARY}\n  $1"
}

# ─── 1. macOS Software Updates ──────────────────────────────────
section "macOS Software Updates"
if command -v gtimeout &>/dev/null; then
    MACOS_UPDATES=$(gtimeout 120 softwareupdate -l 2>&1 || true)
elif command -v timeout &>/dev/null; then
    MACOS_UPDATES=$(timeout 120 softwareupdate -l 2>&1 || true)
else
    MACOS_UPDATES=$(softwareupdate -l 2>&1 || true)
fi
if echo "$MACOS_UPDATES" | grep -q "No new software available"; then
    log "  macOS is up to date"
    add_summary "macOS: Up to date"
else
    log "  Available updates:"
    echo "$MACOS_UPDATES" | tee -a "$LOG_FILE"
    add_summary "macOS: Updates available (see log for details)"
fi

# ─── 2. Mac App Store (mas) ─────────────────────────────────────
section "Mac App Store"
if ! command -v mas &>/dev/null; then
    run_step "Installing mas (Mac App Store CLI)" brew install mas
fi
if command -v mas &>/dev/null; then
    if ! mas account &>/dev/null; then
        log "  Not signed into App Store — skipping"
        add_summary "App Store: Skipped (not signed in)"
    else
        MAS_OUTDATED=$(mas outdated 2>/dev/null || true)
        if [[ -z "$MAS_OUTDATED" ]]; then
            log "  All App Store apps are up to date"
            add_summary "App Store: Up to date"
        else
            log "  Outdated apps:"
            echo "$MAS_OUTDATED" | tee -a "$LOG_FILE"
            run_step "Upgrading App Store apps" mas upgrade
            add_summary "App Store: Updated $(echo "$MAS_OUTDATED" | wc -l | tr -d ' ') app(s)"
        fi
    fi
else
    log "  mas not available — skipping"
    add_summary "App Store: Skipped (mas not installed)"
fi

# ─── 3. Homebrew ────────────────────────────────────────────────
section "Homebrew"
run_step "Updating Homebrew" brew update

BREW_OUTDATED=$(brew outdated 2>/dev/null || true)
if [[ -z "$BREW_OUTDATED" ]]; then
    log "  All formulae are up to date"
    add_summary "Homebrew formulae: Up to date"
else
    log "  Outdated formulae: $BREW_OUTDATED"
    run_step "Upgrading formulae" brew upgrade
    add_summary "Homebrew formulae: Upgraded $(echo "$BREW_OUTDATED" | wc -l | tr -d ' ') package(s)"
fi

# ─── 4. Homebrew Casks ──────────────────────────────────────────
section "Homebrew Casks"
CASK_OUTDATED=$(brew outdated --cask 2>/dev/null || true)
if [[ -z "$CASK_OUTDATED" ]]; then
    log "  All casks are up to date"
    add_summary "Homebrew casks: Up to date"
else
    log "  Outdated casks: $CASK_OUTDATED"
    run_step "Upgrading casks" brew upgrade --cask
    add_summary "Homebrew casks: Upgraded $(echo "$CASK_OUTDATED" | wc -l | tr -d ' ') cask(s)"
fi

# ─── 5. Homebrew Cleanup ────────────────────────────────────────
section "Homebrew Cleanup"
run_step "Cleaning up old versions" brew cleanup
log "→ Running brew doctor"
if $DRY_RUN; then
    log "  [dry-run] Would execute: brew doctor"
    add_summary "Homebrew health: Skipped (dry run)"
else
    DOCTOR_OUTPUT=$(brew doctor 2>&1 || true)
    echo "$DOCTOR_OUTPUT" >> "$LOG_FILE"
    if echo "$DOCTOR_OUTPUT" | grep -q "Your system is ready to brew"; then
        log "  ✓ Done"
        add_summary "Homebrew health: Clean"
    else
        log "  ✗ Warnings found"
        add_summary "Homebrew health: Warnings found (see log)"
    fi
fi

# ─── 6. npm Global Packages ────────────────────────────────────
section "npm Global Packages"
if command -v npm &>/dev/null; then
    run_step "Updating global npm packages" npm update -g

    NPM_OUTDATED=$(npm outdated -g 2>/dev/null || true)
    if [[ -z "$NPM_OUTDATED" ]]; then
        add_summary "npm global: Up to date"
    else
        log "  Still outdated (beyond semver range):"
        echo "$NPM_OUTDATED" | tee -a "$LOG_FILE"
        add_summary "npm global: Some packages outdated beyond semver range"
    fi

    run_step "Updating MCP filesystem server" \
        npm install -g @modelcontextprotocol/server-filesystem@latest
else
    log "  npm not found — skipping"
    add_summary "npm: Not installed"
fi

# ─── 7. pip3 ────────────────────────────────────────────────────
section "Python (pip3)"
if command -v pip3 &>/dev/null; then
    run_step "Upgrading pip, setuptools, wheel" \
        pip3 install --upgrade pip setuptools wheel

    PIP_OUTDATED=$(pip3 list --outdated --format=columns 2>/dev/null || true)
    if [[ -z "$PIP_OUTDATED" ]] || { [[ "$PIP_OUTDATED" == *"Package"*"Version"* ]] && [[ $(echo "$PIP_OUTDATED" | wc -l) -le 2 ]]; }; then
        log "  All pip3 packages are up to date"
        add_summary "pip3: Up to date"
    else
        log "  Outdated packages:"
        echo "$PIP_OUTDATED" | tee -a "$LOG_FILE"
        OUTDATED_COUNT=$(echo "$PIP_OUTDATED" | tail -n +3 | wc -l | tr -d ' ')
        add_summary "pip3: Core tools updated; ${OUTDATED_COUNT} other package(s) outdated (manual review recommended)"
    fi
else
    log "  pip3 not found — skipping"
    add_summary "pip3: Not installed"
fi

# ─── 8. Ruby Gems ─────────────────────────────────────────────
section "Ruby Gems"
if command -v gem &>/dev/null; then
    run_step "Updating RubyGems system" gem update --system
    run_step "Updating installed gems" gem update --no-document
    run_step "Cleaning up old gem versions" gem cleanup

    GEM_OUTDATED=$(gem outdated 2>/dev/null || true)
    if [[ -z "$GEM_OUTDATED" ]]; then
        add_summary "Ruby Gems: Up to date"
    else
        log "  Still outdated:"
        echo "$GEM_OUTDATED" | tee -a "$LOG_FILE"
        OUTDATED_COUNT=$(echo "$GEM_OUTDATED" | wc -l | tr -d ' ')
        add_summary "Ruby Gems: ${OUTDATED_COUNT} gem(s) still outdated (see log)"
    fi
else
    log "  gem not found — skipping"
    add_summary "Ruby Gems: Not installed"
fi

# ─── 9. VS Code ────────────────────────────────────────────────
section "VS Code"
if command -v code &>/dev/null; then
    run_step "Checking for VS Code updates" code --update
    run_step_eval "Updating all VS Code extensions" \
        "code --list-extensions | xargs -L 1 code --install-extension --force"
    add_summary "VS Code: Extensions refreshed"
else
    log "  VS Code CLI not found — skipping"
    add_summary "VS Code: CLI not available"
fi

# ─── Summary ────────────────────────────────────────────────────
section "Summary"
log ""
printf '%b\n' "$SUMMARY" | tee -a "$LOG_FILE"
log ""
log "Daily update complete. Full log: $LOG_FILE"
log "─────────────────────────────────────────────────────────────"
