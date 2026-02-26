#!/usr/bin/env bash
# --- MSP Worktree Safety Guard (Patch L, shared) ---
# shellcheck source=/dev/null
. "$(git rev-parse --show-toplevel 2>/dev/null)/Scripts/lib/worktree_guard.sh"
msp_enforce_main_repo_or_exit
# --- End MSP Worktree Safety Guard (Patch L, shared) ---
# ============================================================================
# Export IPA from Archive for Device Verification
# ============================================================================
# Purpose: Export IPA from xcarchive using xcodebuild
#
# Usage:   ./export_ipa.sh <sandbox_path>
# ============================================================================

set -euo pipefail

source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

export_ipa() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log::error "DEVICE" "Sandbox path required"
        return 1
    fi
    
    if ! command -v xcodebuild >/dev/null 2>&1; then
        vr_log::warn "DEVICE" "[DEVICE] xcodebuild command not found, skipping IPA export"
        return 0
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    local archive_path="$demoapp_dir/DemoApp.xcarchive"
    local export_path="$demoapp_dir/output"
    
    if [[ ! -d "$archive_path" ]]; then
        vr_log::error "DEVICE" "[DEVICE] Archive not found: $archive_path"
        return 1
    fi
    
    local export_options_plist="$demoapp_dir/ExportOptions.plist"
    cat > "$export_options_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF
    
    local export_log
    export_log="$(mktemp)" || {
        vr_log::error "DEVICE" "[DEVICE] Failed to create temporary log file"
        return 1
    }
    
    pushd "$demoapp_dir" >/dev/null || {
        vr_log::error "DEVICE" "[DEVICE] Failed to change to DemoApp directory"
        rm -f "$export_log"
        return 1
    }
    
    vr_log::info "DEVICE" "[DEVICE] Exporting IPA from archive..."
    
    if xcodebuild \
        -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options_plist" \
        >"$export_log" 2>&1; then
        
        local ipa_file
        ipa_file="$(find "$export_path" -name "*.ipa" -type f | head -1)"
        if [[ -n "$ipa_file" ]] && [[ -f "$ipa_file" ]]; then
            vr_log::info "DEVICE" "[DEVICE] IPA exported: $ipa_file"
            rm -f "$export_log"
            popd >/dev/null
            return 0
        else
            vr_log::error "DEVICE" "[DEVICE] IPA file not found after export"
            echo "---------- XCODEBUILD OUTPUT (last 80 lines) ----------"
            tail -n 80 "$export_log" || cat "$export_log"
            echo "------------------------------------------------------"
            rm -f "$export_log"
            popd >/dev/null
            return 1
        fi
    else
        vr_log::error "DEVICE" "[DEVICE] IPA export failed"
        echo "---------- XCODEBUILD OUTPUT (last 80 lines) ----------"
        tail -n 80 "$export_log" || cat "$export_log"
        echo "------------------------------------------------------"
        rm -f "$export_log"
        popd >/dev/null
        return 1
    fi
}

# ============================================================================
# Main
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    export_ipa "$@"
fi

