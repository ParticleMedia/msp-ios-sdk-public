#!/usr/bin/env bash
set -euo pipefail

# DemoApp config helper (config-driven)

DEMOAPP_PODS_CONFIG_FILE="${DEMOAPP_PODS_CONFIG_FILE:-$ROOT_DIR/Scripts/config/demoapp_pods.conf}"

demoapp_load_config() {
    if [[ -f "$DEMOAPP_PODS_CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$DEMOAPP_PODS_CONFIG_FILE"
        return 0
    fi
    return 1
}

# Emit configFiles stanza if xcconfig files exist.
# Args: output_file base_dir rel_debug rel_release indent
emit_demoapp_pods_config_files() {
    local output_file="$1"
    local base_dir="$2"
    local rel_debug="$3"
    local rel_release="$4"
    local indent="${5:-    }"

    if [[ -z "$rel_debug" ]] || [[ -z "$rel_release" ]]; then
        return 0
    fi
    if [[ -f "$base_dir/$rel_debug" ]] && [[ -f "$base_dir/$rel_release" ]]; then
        cat >> "$output_file" <<YAML
${indent}configFiles:
${indent}  Debug: ${rel_debug}
${indent}  Release: ${rel_release}
YAML
    fi
}

export -f demoapp_load_config
export -f emit_demoapp_pods_config_files
