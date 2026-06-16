# Codex ↔ Claude MCP Bridge

An MCP (Model Context Protocol) server that lets **Claude Code** and **OpenAI Codex** agents work together. Either agent can delegate tasks to the other, or they can collaborate on a task with one drafting and the other reviewing.

## How It Works

```
┌──────────────┐         ┌─────────────────┐         ┌──────────────┐
│  Claude Code │◄──MCP──►│  MCP Bridge     │◄──SDK──►│  Codex CLI   │
│  (or Codex)  │  stdio  │  Server         │         │  (subprocess)│
└──────────────┘         │                 │         └──────────────┘
                         │  ┌───────────┐  │
                         │  │ Anthropic │  │         ┌──────────────┐
                         │  │ API       │──┼────────►│  Claude API  │
                         │  └───────────┘  │         └──────────────┘
                         └─────────────────┘
```

The bridge exposes four MCP tools:

| Tool | Description |
|------|-------------|
| `ask_codex` | Send a task to Codex, get back its response + file changes + command output |
| `ask_claude` | Send a task to Claude, get back its response |
| `collaborate` | One agent drafts, the other reviews — produces a combined result |
| `delegate` | Smart routing: auto-picks the best agent based on task type |

## Prerequisites

- **Node.js 18+**
- **Codex CLI** installed (`npm i -g @openai/codex` or `brew install --cask codex`)
- **Anthropic API key** (for `ask_claude` / `collaborate` with Claude)
- **OpenAI API key or ChatGPT login** (for Codex)

## Setup

```bash
cd mcp-bridge
npm install
npm run build
```

### Environment Variables

```bash
# Required for Claude tools
export ANTHROPIC_API_KEY="sk-ant-..."

# Required for Codex tools (or sign in via `codex` CLI)
export OPENAI_API_KEY="sk-..."
```

## Connecting to Claude Code

Add to your Claude Code MCP settings (`.claude/settings.json` or project settings):

```json
{
  "mcpServers": {
    "codex-bridge": {
      "command": "node",
      "args": ["/path/to/codex/mcp-bridge/dist/index.js"],
      "env": {
        "OPENAI_API_KEY": "sk-...",
        "ANTHROPIC_API_KEY": "sk-ant-..."
      }
    }
  }
}
```

Or during development:

```json
{
  "mcpServers": {
    "codex-bridge": {
      "command": "npx",
      "args": ["tsx", "/path/to/codex/mcp-bridge/src/index.ts"],
      "env": {
        "OPENAI_API_KEY": "sk-...",
        "ANTHROPIC_API_KEY": "sk-ant-..."
      }
    }
  }
}
```

## Connecting to Codex (macOS app)

Add to `~/.codex/config.toml`:

```toml
[mcp_servers.claude_bridge]
command = "node"
args = ["/path/to/codex/mcp-bridge/dist/index.js"]

[mcp_servers.claude_bridge.env]
ANTHROPIC_API_KEY = "sk-ant-..."
```

Now when using the macOS Codex app, it can call `ask_claude` and `collaborate` to get Claude's input.

## Usage Examples

### From Claude Code — ask Codex to run tests

Claude Code can use the `ask_codex` tool:
```
"Run the test suite and report any failures"
→ Codex executes tests, returns output + exit codes
```

### From Codex — ask Claude to review code

Codex can use the `ask_claude` tool:
```
"Review this function for security issues: [code]"
→ Claude analyzes and returns findings
```

### Collaboration — both agents work together

Either agent can use the `collaborate` tool:
```
Task: "Implement a rate limiter middleware"
→ Codex writes the code (draft)
→ Claude reviews it (review)
→ Combined output returned
```

### Smart delegation

The `delegate` tool auto-routes based on task type:
- Code execution tasks → Codex (run, build, test, implement, etc.)
- Analysis/reasoning tasks → Claude (review, explain, analyze, etc.)

## Architecture

- **MCP Server**: Uses `@modelcontextprotocol/sdk` for the stdio transport
- **Codex Integration**: Uses `@openai/codex-sdk` TypeScript SDK to spawn Codex as a subprocess
- **Claude Integration**: Uses `@anthropic-ai/sdk` to call the Claude API directly
- **Bidirectional**: Works from both Claude Code and Codex as the host agent
