#!/bin/bash
# ============================================================================
# Export IPA from Archive for Device Verification
# ============================================================================
# Purpose: Export IPA from xcarchive using xcodebuild
#
# Usage:   ./export_ipa.sh <sandbox_path>
# ============================================================================

set -euo pipefail

# Source common utilities
source "$(dirname "$0")/../verify_remote/common/utils.sh"

# ============================================================================
# Functions
# ============================================================================

export_ipa() {
    local sandbox="$1"
    
    if [[ -z "$sandbox" ]]; then
        vr_log_error "Sandbox path required"
        return 1
    fi
    
    # Check if xcodebuild exists
    if ! command -v xcodebuild >/dev/null 2>&1; then
        vr_log_warn "[DEVICE] xcodebuild command not found, skipping IPA export"
        return 0
    fi
    
    local demoapp_dir="$sandbox/DemoApp"
    local archive_path="$demoapp_dir/DemoApp.xcarchive"
    local export_path="$demoapp_dir/output"
    
    # Check if archive exists
    if [[ ! -d "$archive_path" ]]; then
        vr_log_error "[DEVICE] Archive not found: $archive_path"
        return 1
    fi
    
    # Create export options plist
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
    
    # Create temporary log file for xcodebuild output
    local export_log
    export_log="$(mktemp)" || {
        vr_log_error "[DEVICE] Failed to create temporary log file"
        return 1
    }
    
    # Change to DemoApp directory and run xcodebuild export
    pushd "$demoapp_dir" >/dev/null || {
        vr_log_error "[DEVICE] Failed to change to DemoApp directory"
        rm -f "$export_log"
        return 1
    }
    
    vr_log_info "[DEVICE] Exporting IPA from archive..."
    
    # Export command
    if xcodebuild \
        -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options_plist" \
        >"$export_log" 2>&1; then
        
        # Verify IPA exists
        local ipa_file
        ipa_file="$(find "$export_path" -name "*.ipa" -type f | head -1)"
        if [[ -n "$ipa_file" ]] && [[ -f "$ipa_file" ]]; then
            vr_log_info "[DEVICE] IPA exported: $ipa_file"
            rm -f "$export_log"
            popd >/dev/null
            return 0
        else
            vr_log_error "[DEVICE] IPA file not found after export"
            echo "---------- XCODEBUILD OUTPUT (last 80 lines) ----------"
            tail -n 80 "$export_log" || cat "$export_log"
            echo "------------------------------------------------------"
            rm -f "$export_log"
            popd >/dev/null
            return 1
        fi
    else
        vr_log_error "[DEVICE] IPA export failed"
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

