#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { runCodexTask, formatCodexResult } from "./codex-agent.js";
import { runClaudeTask } from "./claude-agent.js";

const server = new McpServer({
  name: "codex-claude-bridge",
  version: "0.1.0",
});

// ── Tool: ask_codex ──────────────────────────────────────────────────
// Delegates a task to the OpenAI Codex agent and returns its response.
server.tool(
  "ask_codex",
  {
    prompt: z.string().describe("The task or question to send to Codex"),
    model: z
      .string()
      .optional()
      .describe('Codex model to use (e.g. "o3", "gpt-4o")'),
    working_directory: z
      .string()
      .optional()
      .describe("Working directory for Codex to operate in"),
    sandbox_mode: z
      .enum(["read-only", "workspace-write", "danger-full-access"])
      .optional()
      .describe("Sandbox mode for Codex execution"),
  },
  async ({ prompt, model, working_directory, sandbox_mode }) => {
    try {
      const result = await runCodexTask(prompt, {
        model,
        workingDirectory: working_directory,
        sandboxMode: sandbox_mode,
      });
      return {
        content: [{ type: "text" as const, text: formatCodexResult(result) }],
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      return {
        content: [
          { type: "text" as const, text: `Codex error: ${msg}` },
        ],
        isError: true,
      };
    }
  },
);

// ── Tool: ask_claude ─────────────────────────────────────────────────
// Delegates a task to Claude and returns its response.
server.tool(
  "ask_claude",
  {
    prompt: z.string().describe("The task or question to send to Claude"),
    model: z
      .string()
      .optional()
      .describe(
        'Claude model to use (e.g. "claude-sonnet-4-20250514", "claude-opus-4-20250514")',
      ),
    system_prompt: z
      .string()
      .optional()
      .describe("System prompt to guide Claude's behavior"),
    max_tokens: z
      .number()
      .optional()
      .describe("Maximum tokens in Claude's response"),
  },
  async ({ prompt, model, system_prompt, max_tokens }) => {
    try {
      const result = await runClaudeTask(prompt, {
        model,
        systemPrompt: system_prompt,
        maxTokens: max_tokens,
      });
      let text = `## Claude Response\n${result.response}`;
      if (result.usage) {
        text += `\n\n---\n*Tokens: ${result.usage.input_tokens} in / ${result.usage.output_tokens} out*`;
      }
      return {
        content: [{ type: "text" as const, text }],
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      return {
        content: [
          { type: "text" as const, text: `Claude error: ${msg}` },
        ],
        isError: true,
      };
    }
  },
);

// ── Tool: collaborate ────────────────────────────────────────────────
// Both agents work on a task: one proposes, the other reviews/refines.
server.tool(
  "collaborate",
  {
    task: z
      .string()
      .describe("The task description for both agents to work on"),
    first_agent: z
      .enum(["codex", "claude"])
      .optional()
      .describe(
        'Which agent drafts first (default: "codex"). The other agent reviews.',
      ),
    working_directory: z
      .string()
      .optional()
      .describe("Working directory (used by Codex)"),
    codex_model: z.string().optional().describe("Model for Codex"),
    claude_model: z.string().optional().describe("Model for Claude"),
  },
  async ({
    task,
    first_agent,
    working_directory,
    codex_model,
    claude_model,
  }) => {
    const drafter = first_agent ?? "codex";
    const reviewer = drafter === "codex" ? "claude" : "codex";
    const parts: string[] = [];

    try {
      // Phase 1: Draft
      parts.push(`# Collaboration: ${drafter} drafts, ${reviewer} reviews\n`);
      parts.push(`## Phase 1: ${drafter} drafts\n`);

      let draftResponse: string;

      if (drafter === "codex") {
        const result = await runCodexTask(task, {
          model: codex_model,
          workingDirectory: working_directory,
          sandboxMode: "read-only",
        });
        draftResponse = formatCodexResult(result);
      } else {
        const result = await runClaudeTask(task, { model: claude_model });
        draftResponse = result.response;
      }

      parts.push(draftResponse);

      // Phase 2: Review
      parts.push(`\n## Phase 2: ${reviewer} reviews\n`);

      const reviewPrompt = [
        `Review and improve the following draft response for this task:`,
        ``,
        `**Original task:** ${task}`,
        ``,
        `**Draft from ${drafter}:**`,
        draftResponse,
        ``,
        `Provide your assessment: what's good, what needs improvement, and your refined version.`,
      ].join("\n");

      let reviewResponse: string;

      if (reviewer === "claude") {
        const result = await runClaudeTask(reviewPrompt, {
          model: claude_model,
          systemPrompt:
            "You are reviewing another AI agent's work. Be constructive and specific. If the draft is good, say so. If it needs changes, explain why and provide the improved version.",
        });
        reviewResponse = result.response;
      } else {
        const result = await runCodexTask(reviewPrompt, {
          model: codex_model,
          workingDirectory: working_directory,
          sandboxMode: "read-only",
        });
        reviewResponse = formatCodexResult(result);
      }

      parts.push(reviewResponse);

      return {
        content: [{ type: "text" as const, text: parts.join("\n") }],
      };
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text" as const,
            text: `Collaboration error: ${msg}\n\nPartial output:\n${parts.join("\n")}`,
          },
        ],
        isError: true,
      };
    }
  },
);

// ── Tool: delegate ───────────────────────────────────────────────────
// Smart delegation: describe a task and let the bridge pick the best agent.
server.tool(
  "delegate",
  {
    task: z.string().describe("The task to delegate"),
    prefer: z
      .enum(["codex", "claude", "auto"])
      .optional()
      .describe(
        '"auto" picks based on task type: Codex for code execution/file changes, Claude for analysis/reasoning',
      ),
    working_directory: z
      .string()
      .optional()
      .describe("Working directory (used when Codex is selected)"),
  },
  async ({ task, prefer, working_directory }) => {
    const choice = prefer ?? "auto";
    let agent: "codex" | "claude";

    if (choice === "auto") {
      const codeKeywords =
        /\b(run|execute|build|test|fix|create file|write file|shell|command|install|deploy|refactor|implement|patch)\b/i;
      agent = codeKeywords.test(task) ? "codex" : "claude";
    } else {
      agent = choice;
    }

    try {
      if (agent === "codex") {
        const result = await runCodexTask(task, {
          workingDirectory: working_directory,
          sandboxMode: "read-only",
        });
        return {
          content: [
            {
              type: "text" as const,
              text: `*Delegated to Codex*\n\n${formatCodexResult(result)}`,
            },
          ],
        };
      } else {
        const result = await runClaudeTask(task);
        return {
          content: [
            {
              type: "text" as const,
              text: `*Delegated to Claude*\n\n## Claude Response\n${result.response}`,
            },
          ],
        };
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text" as const,
            text: `Delegation error (${agent}): ${msg}`,
          },
        ],
        isError: true,
      };
    }
  },
);

// ── Start ────────────────────────────────────────────────────────────
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("MCP Bridge fatal error:", err);
  process.exit(1);
});
