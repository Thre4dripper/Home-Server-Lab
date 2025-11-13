#!/bin/bash

set -e

# Track hardware paths we might want to expose to the container
declare -a HA_DEVICE_LIST=()
declare -A HA_DEVICE_SEEN=()
declare -a TRUSTED_PROXY_LIST=()
declare -a DEFAULT_TRUSTED_PROXIES=("127.0.0.1" "::1" "172.16.0.0/12")
PYTHON_BIN=""

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_python() {
    if command_exists python3; then
        PYTHON_BIN="python3"
    elif command_exists python; then
        PYTHON_BIN="python"
    else
        PYTHON_BIN=""
    fi
}

if command_exists sudo && [[ $EUID -ne 0 ]]; then
    SUDO_BIN="sudo"
else
    SUDO_BIN=""
fi

run_privileged() {
    if [[ -n "$SUDO_BIN" ]]; then
        $SUDO_BIN "$@"
    else
        "$@"
    fi
}

record_device_candidate() {
    local dev="$1"
    [[ -e "$dev" ]] || return
    if [[ -z "${HA_DEVICE_SEEN[$dev]}" ]]; then
        HA_DEVICE_SEEN["$dev"]=1
        HA_DEVICE_LIST+=("$dev")
    fi
}

trim_string() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

describe_char_device() {
    local dev="$1"
    if command_exists stat; then
        stat -c "%a %U:%G" "$dev" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

build_trusted_proxy_list() {
    TRUSTED_PROXY_LIST=()
    local -a raw_list=("${DEFAULT_TRUSTED_PROXIES[@]}")

    if [[ -n "${HA_TRUSTED_PROXIES:-}" ]]; then
        IFS=',' read -ra user_list <<< "${HA_TRUSTED_PROXIES}"
        for entry in "${user_list[@]}"; do
            local cleaned
            cleaned=$(trim_string "$entry")
            [[ -n "$cleaned" ]] && raw_list+=("$cleaned")
        done
    fi

    local -A seen=()
    for entry in "${raw_list[@]}"; do
        [[ -z "$entry" ]] && continue
        if [[ -z "${seen[$entry]}" ]]; then
            seen["$entry"]=1
            TRUSTED_PROXY_LIST+=("$entry")
        fi
    done
}

render_http_snippet() {
    local outfile="$1"
    {
        echo "# --- BEGIN setup.sh managed http block ---"
        echo "http:"
        echo "  use_x_forwarded_for: true"
        echo "  trusted_proxies:"
        for proxy in "${TRUSTED_PROXY_LIST[@]}"; do
            echo "    - $proxy"
        done
        echo "# --- END setup.sh managed http block ---"
    } > "$outfile"
}

ensure_base_configuration() {
    local config_file="./config/configuration.yaml"
    if [[ -f "$config_file" ]]; then
        return
    fi

    echo "🆕 Creating baseline configuration.yaml"
    local tmpfile
    tmpfile=$(mktemp)
    cat <<'EOF' > "$tmpfile"

# Loads default set of integrations. Do not remove.
default_config:

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
EOF

    if [[ -n "$SUDO_BIN" ]]; then
        $SUDO_BIN mv "$tmpfile" "$config_file"
        $SUDO_BIN chmod 644 "$config_file"
    else
        mv "$tmpfile" "$config_file"
        chmod 644 "$config_file"
    fi
}

ensure_reverse_proxy_whitelist() {
    local config_file="./config/configuration.yaml"
    if [[ ! -f "$config_file" ]]; then
        echo "⚠️  configuration.yaml not found; skipping trusted proxy update for now."
        return
    fi

    if [[ -z "$PYTHON_BIN" ]]; then
        echo "⚠️  Python is not available. Cannot manage trusted proxy block automatically."
        return
    fi

    local snippet_file
    snippet_file=$(mktemp)
    render_http_snippet "$snippet_file"

    local result
    if result=$(run_privileged "$PYTHON_BIN" - "$config_file" "$snippet_file" <<'PY'
import sys, pathlib

cfg = pathlib.Path(sys.argv[1])
snippet = pathlib.Path(sys.argv[2]).read_text().strip() + "\n"
start = "# --- BEGIN setup.sh managed http block ---"
end = "# --- END setup.sh managed http block ---"
text = cfg.read_text()
updated = False

if start in text and end in text:
    before, rest = text.split(start, 1)
    body, after = rest.split(end, 1)
    existing = (start + body + end).strip() + "\n"
    if existing != snippet:
        new_text = before.rstrip() + "\n" + snippet + "\n" + after.lstrip()
        updated = True
    else:
        new_text = text
else:
    new_text = snippet + "\n\n" + text.lstrip()
    updated = True

if updated:
    cfg.write_text(new_text)

print("UPDATED" if updated else "NOCHANGE")
PY
    ); then
        if [[ "$result" == *"UPDATED"* ]]; then
            echo "✅ Ensured reverse proxy whitelist in configuration.yaml"
        else
            echo "ℹ️  Reverse proxy whitelist already up to date"
        fi
    else
        echo "❌ Failed to update reverse proxy whitelist (see errors above)"
    fi

    rm -f "$snippet_file"
}

print_network_summary() {
    echo "   • Network interfaces:"
    if ! command_exists ip; then
        echo "     - 'ip' command not found"
        return
    fi

    local ip_output=""
    if ip_output=$(ip -brief link show 2>/dev/null); then
        :
    elif [[ -n "$SUDO_BIN" ]] && ip_output=$(run_privileged ip -brief link show 2>/dev/null); then
        :
    fi

    if [[ -z "$ip_output" ]]; then
        echo "     - Unable to query links (insufficient permissions?)"
        return
    fi

    while read -r name state rest; do
        [[ -z "$name" ]] && continue
        printf "     - %-12s %s\n" "$name" "($state)"
    done <<< "$ip_output"
}

print_bluetooth_summary() {
    echo "   • Bluetooth adapters:"
    local found=false
    if [[ -d /sys/class/bluetooth ]]; then
        for adapter_path in /sys/class/bluetooth/*; do
            [[ -e "$adapter_path" ]] || continue
            local adapter
            adapter=$(basename "$adapter_path")
            found=true
            local driver="unknown"
            if [[ -f "$adapter_path/device/uevent" ]]; then
                driver=$(grep -m1 "^DRIVER=" "$adapter_path/device/uevent" 2>/dev/null | cut -d= -f2)
                [[ -n "$driver" ]] || driver="unknown"
            fi
            local backing_dev
            backing_dev=$(readlink -f "$adapter_path/device" 2>/dev/null || echo "unknown")
            echo "     - $adapter (driver: $driver, sysfs: $backing_dev)"
        done
    fi
    if [[ "$found" == false ]]; then
        echo "     - None detected"
    fi
}

print_serial_summary() {
    echo "   • Serial / TTY devices:"
    local found=false
    for dev in /dev/ttyAMA* /dev/ttyUSB* /dev/ttyACM*; do
        [[ -e "$dev" ]] || continue
        found=true
        local meta
        meta=$(describe_char_device "$dev")
        echo "     - $dev (perm $meta)"
        record_device_candidate "$dev"
    done
    if [[ "$found" == false ]]; then
        echo "     - None detected"
    fi
}

print_usb_summary() {
    echo "   • USB devices:"
    if ! command_exists lsusb; then
        echo "     - 'lsusb' not available (install usbutils)"
        return
    fi

    local usb_output
    if usb_output=$(lsusb 2>/dev/null); then
        :
    elif [[ -n "$SUDO_BIN" ]] && usb_output=$(run_privileged lsusb 2>/dev/null); then
        :
    else
        echo "     - Unable to read USB bus (permission denied)"
        return
    fi

    if [[ -n "$usb_output" ]]; then
        while IFS= read -r line; do
            echo "     - $line"
        done <<< "$usb_output"
    else
        echo "     - No USB devices reported"
    fi
}

print_device_mapping_hint() {
    if ((${#HA_DEVICE_LIST[@]} == 0)); then
        return
    fi

    echo ""
    echo "🔌 Device mapping suggestions for docker-compose:"
    for dev in "${HA_DEVICE_LIST[@]}"; do
        echo "   - $dev:$dev"
    done
    echo "   (Add under the 'devices:' section if the integration requires direct access)"
}

print_trusted_proxy_summary() {
    echo "🛡️  Trusted reverse proxies to whitelist:"
    if ((${#TRUSTED_PROXY_LIST[@]} == 0)); then
        echo "   - (none)"
    else
        for proxy in "${TRUSTED_PROXY_LIST[@]}"; do
            echo "   - $proxy"
        done
    fi
    if [[ -n "${HA_TRUSTED_PROXIES:-}" ]]; then
        echo "   (Using custom HA_TRUSTED_PROXIES value)"
    else
        echo "   (Override via HA_TRUSTED_PROXIES=\"cidr,cidr\")"
    fi
    echo ""
}

print_hardware_snapshot() {
    echo "🛰️  Host hardware snapshot"
    echo "   (Use this list to decide which /dev nodes to map into the container)"
    print_network_summary
    print_bluetooth_summary
    print_serial_summary
    print_usb_summary
    print_device_mapping_hint
    echo ""
}

detect_python
build_trusted_proxy_list

echo "🏠 Home Assistant Setup"
echo "======================="
echo ""
echo "📝 Configuration:"
echo "   • Config: Persistent volume for configuration"
echo "   • Network: Host mode for full access to hardware"
echo "   • Access: Web interface on port 8123"
echo ""

# Create config directory if it doesn't exist
if [ ! -d "./config" ]; then
    mkdir -p config
    echo "✅ Created config directory"
fi
ensure_base_configuration

# Auto-detect network configuration
HOST_IP=$(hostname -I | awk '{print $1}')

echo "📍 Host Configuration: $HOST_IP"
print_hardware_snapshot
print_trusted_proxy_summary
ensure_reverse_proxy_whitelist

# Start Home Assistant
echo "🚀 Starting Home Assistant..."
echo "   • Home Assistant will be ready in 1-2 minutes on first run"
echo ""

docker compose up -d

# Wait for services to start
echo "⏳ Waiting for Home Assistant to start..."
echo "   • This may take 1-2 minutes on first run..."

# Wait for Home Assistant to be ready
echo -n "   • Home Assistant: "
for i in {1..60}; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8123 | grep -q "200\|302"; then
        echo "✅ Ready"
        break
    elif [ $i -eq 60 ]; then
        echo "❌ Timeout"
        echo "     Check logs: docker compose logs homeassistant"
        exit 1
    else
        echo -n "."
        sleep 2
    fi
done

# Test setup
echo ""
echo "🧪 Testing Home Assistant Setup..."

# Test web interface
echo -n "Web Interface:     "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8123 | grep -q "200\|302"; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
fi

# Test data persistence
echo -n "Config Persistence:"
if [ -d "./config" ]; then
    echo "✅ Volume mounted"
else
    echo "❌ Volume issues"
fi

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "   • Web Interface: http://$HOST_IP:8123"
echo "   • First time setup: Follow the on-screen instructions"
echo ""
echo "📱 Next Steps:"
echo "   1. Access Home Assistant at: http://$HOST_IP:8123"
echo "   2. Complete the initial setup wizard"
echo "   3. Add your smart home devices and integrations"
echo ""
echo "🔧 Management Commands:"
echo "   • View logs:    docker compose logs -f"
echo "   • Stop:         docker compose down"
echo "   • Restart:      docker compose restart"
echo "   • Update:       docker compose pull && docker compose up -d"
echo ""
echo "⚠️  Note: Configuration is persistent in ./config"
echo "💡 For advanced configuration, edit files in ./config"
