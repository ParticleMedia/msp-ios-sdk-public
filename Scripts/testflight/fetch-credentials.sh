#!/usr/bin/env bash
# ============================================================================
# TestFlight Credentials Fetcher
# ============================================================================
# Clones the private credentials repo and installs all signing credentials:
#   - AuthKey_*.p8    → Scripts/testflight/ (for ASC API auth)
#   - Distribution.p12 → imported into login Keychain (for code signing)
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
# ============================================================================

set -euo pipefail

# ---- Constants ----
DEFAULT_CREDENTIALS_REPO="git@github.com:ParticleMedia/msp-ios-credentials.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

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

# Use a temp directory; clean up on exit regardless of success/failure
TMPDIR_CREDS="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CREDS"' EXIT

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

# ---- Install Distribution.p12 into Keychain ----
P12_FILE="$CREDS_TF_DIR/Distribution.p12"
if [[ -f "$P12_FILE" ]]; then
    # Read password from .env
    DIST_CERT_PASSWORD=""
    if grep -q "^DIST_CERT_PASSWORD=" "$DEST_ENV" 2>/dev/null; then
        DIST_CERT_PASSWORD="$(grep "^DIST_CERT_PASSWORD=" "$DEST_ENV" | cut -d'=' -f2-)"
    fi

    log_info "Importing Distribution certificate into Keychain..."
    security import "$P12_FILE" \
        -k "$KEYCHAIN" \
        -P "$DIST_CERT_PASSWORD" \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        2>&1 || {
        # "already exists" is not a fatal error
        log_info "Certificate may already be in Keychain (skipping)"
    }

    # Allow codesign to access the key without UI prompt
    security set-key-partition-list \
        -S "apple-tool:,apple:,codesign:" \
        -s -k "" \
        "$KEYCHAIN" \
        2>/dev/null || true

    log_info "Distribution certificate installed"
else
    log_info "No Distribution.p12 found — skipping Keychain import"
fi

log_success "Credentials ready. You can now run: make beta"
