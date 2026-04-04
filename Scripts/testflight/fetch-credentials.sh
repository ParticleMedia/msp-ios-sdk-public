#!/usr/bin/env bash
# ============================================================================
# TestFlight Credentials Fetcher
# ============================================================================
# Clones the private credentials repo and installs all signing credentials:
#   - AuthKey_*.p8    → Scripts/testflight/ (for ASC API auth)
#   - Distribution.p12 → imported into dedicated CI keychain (msp-build.keychain)
#   - .env            → Scripts/testflight/ (env vars for deploy.sh)
#
# Usage:
#   ./Scripts/testflight/fetch-credentials.sh
#   ./Scripts/testflight/fetch-credentials.sh --repo git@github.com:Org/repo.git
#
# The credentials repo is expected to have this layout:
#   testflight/
#   ├── .env               # ASC_KEY_ID, ASC_ISSUER_ID, DIST_CERT_PASSWORD
#   ├── AuthKey_*.p8       # App Store Connect private key
#   └── Distribution.p12  # iOS Distribution certificate + private key
#
# After this script runs, deploy.sh can be run immediately.
# Cleanup is automatic: deploy.sh restores the keychain list and deletes
# msp-build.keychain on EXIT (via trap), so other CI jobs are not affected.
# ============================================================================

set -euo pipefail

# ---- Constants ----
DEFAULT_CREDENTIALS_REPO="git@github.com:ParticleMedia/msp-ios-credentials.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Dedicated CI keychain — avoids login keychain password issues in headless CI.
# Uses a fixed known password so set-key-partition-list always succeeds.
_ci_keychain_suffix_source="${BUILD_TAG:-${JOB_NAME:-local}-${BUILD_NUMBER:-$$}}"
_ci_keychain_suffix="$(printf '%s' "$_ci_keychain_suffix_source" | tr -cs 'A-Za-z0-9._-' '_')"
CI_KEYCHAIN_NAME="msp-build-${_ci_keychain_suffix}.keychain"
CI_KEYCHAIN_PASSWORD="msp-ci-build"
CI_KEYCHAIN_RESTORE_FILE="$SCRIPT_DIR/.keychain_restore_${_ci_keychain_suffix}"
unset _ci_keychain_suffix_source _ci_keychain_suffix

# ---- Parse arguments ----
CREDENTIALS_REPO="${CREDENTIALS_REPO_URL:-$DEFAULT_CREDENTIALS_REPO}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --repo requires a value" >&2
                exit 1
            fi
            CREDENTIALS_REPO="$2"
            shift 2
            ;;
        --help|-h)
            sed -n '3,22p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ---- Logging (inline, no common.sh dependency) ----
_log() { echo "[$(date '+%H:%M:%S')] [$1] $2"; }
log_info()    { _log "TF-CREDS  INFO" "$1"; }
log_success() { _log "TF-CREDS    OK" "$1"; }
log_error()   { _log "TF-CREDS ERROR" "$1" >&2; }

# ---- Main ----
log_info "Fetching credentials from: $CREDENTIALS_REPO"

# Use a temp directory; clean up on exit regardless of success/failure.
# On failure also remove any partially-installed credential files from the
# workspace — they contain sensitive key material and must not linger.
TMPDIR_CREDS="$(mktemp -d)"
_CREDS_SUCCESS=false
_creds_cleanup() {
    rm -rf "$TMPDIR_CREDS"
    if [[ "$_CREDS_SUCCESS" != "true" ]]; then
        rm -f "$SCRIPT_DIR"/AuthKey_*.p8 "$SCRIPT_DIR/.env" 2>/dev/null || true
    fi
}
trap '_creds_cleanup' EXIT

# Clone (shallow, no history needed)
if ! git clone --depth 1 --quiet "$CREDENTIALS_REPO" "$TMPDIR_CREDS/credentials" 2>&1; then
    log_error "Failed to clone credentials repo: $CREDENTIALS_REPO"
    log_error "Ensure you have SSH access or set CREDENTIALS_REPO_URL."
    exit 1
fi

CREDS_TF_DIR="$TMPDIR_CREDS/credentials/testflight"

# Validate expected layout
if [[ ! -f "$CREDS_TF_DIR/.env" ]]; then
    log_error "Missing testflight/.env in credentials repo"
    exit 1
fi

# ---- Install .p8 ----
p8_files=("$CREDS_TF_DIR"/AuthKey_*.p8)
if [[ ${#p8_files[@]} -eq 0 ]] || [[ ! -f "${p8_files[0]}" ]]; then
    log_error "No AuthKey_*.p8 found in testflight/ of credentials repo"
    exit 1
fi
if [[ ${#p8_files[@]} -gt 1 ]]; then
    log_error "Multiple .p8 files found in credentials repo — expected exactly one"
    exit 1
fi

P8_FILE="${p8_files[0]}"
P8_FILENAME="$(basename "$P8_FILE")"
DEST_P8="$SCRIPT_DIR/$P8_FILENAME"

cp "$P8_FILE" "$DEST_P8"
chmod 600 "$DEST_P8"
log_info "Installed: Scripts/testflight/$P8_FILENAME"

# ---- Install .env ----
DEST_ENV="$SCRIPT_DIR/.env"
cp "$CREDS_TF_DIR/.env" "$DEST_ENV"

# Set ASC_KEY_PATH to correct absolute local path
if grep -q "^ASC_KEY_PATH=" "$DEST_ENV" 2>/dev/null; then
    sed -i '' "s|^ASC_KEY_PATH=.*|ASC_KEY_PATH=$DEST_P8|" "$DEST_ENV"
else
    echo "ASC_KEY_PATH=$DEST_P8" >> "$DEST_ENV"
fi
chmod 600 "$DEST_ENV"
log_info "Installed: Scripts/testflight/.env"

# Publish CI keychain metadata for later stages (deploy.sh / export.sh / Jenkins
# post-cleanup run in separate shells, so they must reload these values from .env).
if grep -q "^CI_KEYCHAIN_NAME=" "$DEST_ENV" 2>/dev/null; then
    sed -i '' "s|^CI_KEYCHAIN_NAME=.*|CI_KEYCHAIN_NAME=$CI_KEYCHAIN_NAME|" "$DEST_ENV"
else
    echo "CI_KEYCHAIN_NAME=$CI_KEYCHAIN_NAME" >> "$DEST_ENV"
fi
if grep -q "^CI_KEYCHAIN_PASSWORD=" "$DEST_ENV" 2>/dev/null; then
    sed -i '' "s|^CI_KEYCHAIN_PASSWORD=.*|CI_KEYCHAIN_PASSWORD=$CI_KEYCHAIN_PASSWORD|" "$DEST_ENV"
else
    echo "CI_KEYCHAIN_PASSWORD=$CI_KEYCHAIN_PASSWORD" >> "$DEST_ENV"
fi
if grep -q "^CI_KEYCHAIN_RESTORE_FILE=" "$DEST_ENV" 2>/dev/null; then
    sed -i '' "s|^CI_KEYCHAIN_RESTORE_FILE=.*|CI_KEYCHAIN_RESTORE_FILE=$CI_KEYCHAIN_RESTORE_FILE|" "$DEST_ENV"
else
    echo "CI_KEYCHAIN_RESTORE_FILE=$CI_KEYCHAIN_RESTORE_FILE" >> "$DEST_ENV"
fi

# ---- Install Distribution.p12 into dedicated CI keychain ----
P12_FILE="$CREDS_TF_DIR/Distribution.p12"
if [[ -f "$P12_FILE" ]]; then
    # Read password from .env
    DIST_CERT_PASSWORD=""
    if grep -q "^DIST_CERT_PASSWORD=" "$DEST_ENV" 2>/dev/null; then
        DIST_CERT_PASSWORD="$(grep "^DIST_CERT_PASSWORD=" "$DEST_ENV" | cut -d'=' -f2-)"
    fi

    log_info "Setting up CI keychain: $CI_KEYCHAIN_NAME"
    # Delete stale keychain from a previous failed run, if any
    security delete-keychain "$CI_KEYCHAIN_NAME" 2>/dev/null || true
    security create-keychain -p "$CI_KEYCHAIN_PASSWORD" "$CI_KEYCHAIN_NAME"
    # No auto-lock: omit -t (no timeout) and omit -u (no lock-on-sleep).
    # Previous -t 3600 -u caused errSecInternalComponent when archive ran long
    # or Mac Studio briefly slept between stages.
    security set-keychain-settings "$CI_KEYCHAIN_NAME"
    security unlock-keychain -p "$CI_KEYCHAIN_PASSWORD" "$CI_KEYCHAIN_NAME"

    log_info "Importing Distribution certificate..."
    security import "$P12_FILE" \
        -k "$CI_KEYCHAIN_NAME" \
        -P "$DIST_CERT_PASSWORD" \
        -T /usr/bin/codesign \
        -T /usr/bin/security

    # Allow codesign to access the key without UI prompt.
    # Uses the known CI keychain password — this is why we avoid login.keychain-db.
    security set-key-partition-list \
        -S "apple-tool:,apple:,codesign:" \
        -s -k "$CI_KEYCHAIN_PASSWORD" \
        "$CI_KEYCHAIN_NAME"

    # Save original keychain list so deploy.sh can restore it after build.
    # Filter out any stale msp-build.keychain reference left from a previous
    # failed run — otherwise the restore would point to a deleted keychain.
    _existing_keychains="$(security list-keychains -d user \
        | tr -d '"' \
        | grep -v "$CI_KEYCHAIN_NAME" \
        | tr '\n' ' ')"
    echo "$_existing_keychains" > "$CI_KEYCHAIN_RESTORE_FILE"
    # Prepend CI keychain to search list, preserving existing keychains
    # shellcheck disable=SC2086
    security list-keychains -d user -s "$CI_KEYCHAIN_NAME" $_existing_keychains
    unset _existing_keychains

    log_info "Distribution certificate installed in $CI_KEYCHAIN_NAME"
else
    log_info "No Distribution.p12 found — skipping Keychain import"
fi

_CREDS_SUCCESS=true
log_success "Credentials ready. You can now run: make beta"
