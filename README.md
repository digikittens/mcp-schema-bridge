# DigiKitten MCP Schema Bridge

**One-command fix for the Claude Desktop App filesystem MCP error.**

> *In memory of Amy Elizabeth Stills — who never gave up on anything worth fighting for.*

---

## The Problem

After a Claude Desktop App update (v2.9939.2+), the built-in MCP client was upgraded to validate JSON Schema using **draft 2020-12 only**. The official `@modelcontextprotocol/server-filesystem` package declares its schemas using **draft-07**, which now causes the app to reject all filesystem tools with this error:

```
Error: Tool 'list_allowed_directories' has an invalid outputSchema:
JSON Schema declares an unsupported dialect
("$schema": "http://json-schema.org/draft-07/schema#").
The default validator supports JSON Schema 2020-12 only.
```

This broke filesystem MCP access for **tens of thousands of users** on both Mac and Windows — including Anthropic's own first-party server (GitHub issues #94351, #87633).

The Claude Code CLI already has the fix. The Desktop app does not yet.

---

## The Fix

A lightweight Python bridge sits between Claude Desktop and the filesystem MCP server. It intercepts the tool list response and strips the `$schema` key before the validator ever sees it. The app accepts the tools, everything works.

No rebuild. No waiting for Anthropic. One command.

---

## Install (macOS)

**Requirements:** Python 3 (pre-installed on all modern Macs), Claude Desktop app, Node.js/npx

```bash
bash ~/Desktop/repository/digikitten-install.sh
```

Or if you've downloaded this repo:

```bash
bash digikitten-install.sh
```

The installer will:
1. Write `mcp-bridge.py` to your home folder
2. Back up your existing Claude config automatically
3. Wrap your filesystem MCP server with the bridge
4. Verify everything is valid before finishing
5. Tell you if it's already installed (safe to run twice)

Then: **Quit Claude Desktop (Cmd+Q) and reopen it.** Your filesystem tools will work.

---

## Uninstall / Restore

If anything goes wrong, restore your original config:

```bash
cp ~/Library/Application\ Support/Claude/claude_desktop_config.json.backup \
   ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

Then restart Claude Desktop.

---

## How It Works

The bridge is a Python stdio proxy. Claude Desktop launches it instead of the MCP server directly. It passes all communication through unchanged — except when it sees a `tools/list` response, it recursively removes any `$schema` key from the tool definitions before forwarding them to the app.

```
Claude Desktop App
      ↕ stdio
mcp-bridge.py  ← strips "$schema" from tools/list responses
      ↕ stdio
@modelcontextprotocol/server-filesystem
```

The fix is ~50 lines of Python. No dependencies beyond the standard library.

---

## Windows

The bridge script (`mcp-bridge.py`) works on Windows too — Python 3 is cross-platform. A Windows installer (`.bat` or `.exe`) is in progress. Community-tested. PRs welcome.

---

## Files

| File | Purpose |
|------|---------|
| `digikitten-install.sh` | macOS one-command installer |
| `mcp-bridge.py` | The bridge (written by installer, or copy manually) |

---

## Who Built This

This fix was figured out overnight by a pro se litigant, Claude (Anthropic's AI), and Gemini (Google's AI) — working together because Anthropic's own engineering team hadn't shipped the fix yet.

It was built in memory of **Amy Elizabeth Stills**, whose spirit of creative community and never giving up on people is what DigiKitten always stood for.

If this saved you hours of frustration, consider leaving a star ⭐

---

## Related GitHub Issues

- [anthropics/claude-code #94351](https://github.com/anthropics/claude-code/issues/94351) — First-party filesystem MCP broken
- [anthropics/claude-code #87633](https://github.com/anthropics/claude-code/issues/87887) — Windows MSIX affected

---

## License

MIT — use it, share it, fix it, ship it.

*DigiKitten was a graphic design and creative community active 2002–2018. This project carries that name forward.*
