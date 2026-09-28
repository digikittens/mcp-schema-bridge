#!/bin/bash

# ============================================================
# DigiKitten MCP Bridge Installer for macOS
# Fixes Claude Desktop App filesystem MCP draft-07 error
# Built by Michael Stills, Claude & Gemini — in Amy's name
# ============================================================

set -e

BRIDGE_PATH="$HOME/mcp-bridge.py"
CONFIG_PATH="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
BACKUP_PATH="$HOME/Library/Application Support/Claude/claude_desktop_config.json.backup"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         DigiKitten MCP Bridge Installer              ║"
echo "║     Claude Desktop App Filesystem Fix for macOS      ║"
echo "║                                                       ║"
echo "║  In memory of Amy Elizabeth Stills                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Step 1: Write the bridge script
echo "→ Writing mcp-bridge.py to $BRIDGE_PATH..."

cat << 'BRIDGE' > "$BRIDGE_PATH"
#!/usr/bin/env python3
"""
DigiKitten MCP Schema Bridge
Fixes Claude Desktop App JSON Schema draft-07 validation error.
Strips the $schema key from MCP tool list responses so the app
accepts them without crashing.

In memory of Amy Elizabeth Stills.
"""
import sys
import json
import subprocess
import threading

def clean_schema(data):
    if isinstance(data, dict):
        data.pop("$schema", None)
        return {k: clean_schema(v) for k, v in data.items()}
    elif isinstance(data, list):
        return [clean_schema(item) for item in data]
    return data

def handle_server_output(proc):
    try:
        for line in proc.stdout:
            try:
                packet = json.loads(line)
                if "result" in packet and "tools" in packet["result"]:
                    packet["result"]["tools"] = clean_schema(packet["result"]["tools"])
                sys.stdout.write(json.dumps(packet) + "\n")
                sys.stdout.flush()
            except json.JSONDecodeError:
                sys.stdout.write(line)
                sys.stdout.flush()
    except Exception as e:
        sys.stderr.write(f"[DigiKitten Bridge Error] {e}\n")

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: mcp-bridge <actual-server-command> [args...]\n")
        sys.exit(1)
    cmd = sys.argv[1:]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=sys.stderr, text=True)
    threading.Thread(target=handle_server_output, args=(proc,), daemon=True).start()
    try:
        for line in sys.stdin:
            proc.stdin.write(line)
            proc.stdin.flush()
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        proc.terminate()

if __name__ == "__main__":
    main()
BRIDGE

chmod +x "$BRIDGE_PATH"
echo "  ✓ Bridge script written"

# Step 2: Check config exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo ""
    echo "✗ ERROR: Claude Desktop config not found at:"
    echo "  $CONFIG_PATH"
    echo ""
    echo "  Make sure Claude Desktop app is installed and has been launched at least once."
    exit 1
fi

# Step 3: Backup the config
echo "→ Backing up config to claude_desktop_config.json.backup..."
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "  ✓ Backup saved"

# Step 4: Check if filesystem MCP is configured
HAS_FILESYSTEM=$(python3 -c "
import json
with open('$CONFIG_PATH') as f:
    config = json.load(f)
mcp = config.get('mcpServers', {})
print('yes' if 'filesystem' in mcp else 'no')
")

if [ "$HAS_FILESYSTEM" = "no" ]; then
    echo ""
    echo "⚠  No 'filesystem' MCP server found in your config."
    echo ""
    echo "   Your config has these MCP servers:"
    python3 -c "
import json
with open('$CONFIG_PATH') as f:
    config = json.load(f)
for key in config.get('mcpServers', {}).keys():
    print(f'   - {key}')
"
    echo ""
    echo "   The bridge wraps an existing 'filesystem' server entry."
    echo "   If your server has a different name, edit this script"
    echo "   and change 'filesystem' to match your server name, then re-run."
    exit 1
fi

# Step 5: Check if already wrapped
ALREADY_WRAPPED=$(python3 -c "
import json
with open('$CONFIG_PATH') as f:
    config = json.load(f)
fs = config.get('mcpServers', {}).get('filesystem', {})
cmd = fs.get('command', '')
args = fs.get('args', [])
already = 'mcp-bridge' in cmd or (len(args) > 0 and 'mcp-bridge' in str(args[0]))
print('yes' if already else 'no')
")

if [ "$ALREADY_WRAPPED" = "yes" ]; then
    echo ""
    echo "✓ Your filesystem MCP is already wrapped with the bridge."
    echo "  Nothing to do — restart Claude Desktop app if still seeing errors."
    exit 0
fi

# Step 6: Show current filesystem path(s)
echo "→ Reading your current filesystem MCP configuration..."
python3 -c "
import json
with open('$CONFIG_PATH') as f:
    config = json.load(f)
fs = config.get('mcpServers', {}).get('filesystem', {})
args = fs.get('args', [])
paths = [a for a in args if not a.startswith('-') and not a.startswith('@') and '/' in a]
print('  Detected path(s): ' + (', '.join(paths) if paths else 'none found'))
"

# Step 7: Apply the bridge
echo "→ Applying bridge to filesystem MCP server..."
python3 << PYEOF
import json

config_path = "$CONFIG_PATH"
bridge_path = "$HOME/mcp-bridge.py"

with open(config_path, 'r') as f:
    config = json.load(f)

fs = config['mcpServers']['filesystem']
original_cmd = fs.get('command', 'npx')
original_args = fs.get('args', [])

new_entry = {
    "command": "python3",
    "args": [bridge_path, original_cmd] + original_args
}

for k, v in fs.items():
    if k not in ('command', 'args'):
        new_entry[k] = v

config['mcpServers']['filesystem'] = new_entry

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print("  ✓ Config updated successfully")
PYEOF

# Step 8: Verify valid JSON
echo "→ Verifying config is valid JSON..."
python3 -c "
import json
with open('$CONFIG_PATH') as f:
    config = json.load(f)
print('  ✓ Config is valid JSON')
"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║                 ✓ INSTALL COMPLETE                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Next steps:"
echo "  1. Quit Claude Desktop app completely (Cmd+Q)"
echo "  2. Reopen Claude Desktop app"
echo "  3. Your filesystem MCP tools should now work"
echo ""
echo "  To restore original config if needed:"
echo "  cp \"$HOME/Library/Application Support/Claude/claude_desktop_config.json.backup\" \\"
echo "     \"$HOME/Library/Application Support/Claude/claude_desktop_config.json\""
echo ""
echo "  DigiKitten MCP Bridge — in memory of Amy Elizabeth Stills"
echo ""
