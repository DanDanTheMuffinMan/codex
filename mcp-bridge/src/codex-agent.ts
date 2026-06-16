import { Codex } from "@openai/codex-sdk";
import type {
  ThreadEvent,
  ThreadItem,
  CommandExecutionItem,
  FileChangeItem,
  AgentMessageItem,
} from "@openai/codex-sdk";

export interface CodexResult {
  response: string;
  items: ThreadItem[];
  usage: { input_tokens: number; output_tokens: number } | null;
}

export async function runCodexTask(
  prompt: string,
  options: {
    model?: string;
    workingDirectory?: string;
    sandboxMode?: "read-only" | "workspace-write" | "danger-full-access";
  } = {},
): Promise<CodexResult> {
  const codex = new Codex();
  const thread = codex.startThread({
    model: options.model,
    workingDirectory: options.workingDirectory,
    sandboxMode: options.sandboxMode ?? "read-only",
    approvalPolicy: "never",
  });

  const turn = await thread.run(prompt);

  return {
    response: turn.finalResponse,
    items: turn.items,
    usage: turn.usage,
  };
}

export async function* streamCodexTask(
  prompt: string,
  options: {
    model?: string;
    workingDirectory?: string;
    sandboxMode?: "read-only" | "workspace-write" | "danger-full-access";
  } = {},
): AsyncGenerator<ThreadEvent> {
  const codex = new Codex();
  const thread = codex.startThread({
    model: options.model,
    workingDirectory: options.workingDirectory,
    sandboxMode: options.sandboxMode ?? "read-only",
    approvalPolicy: "never",
  });

  const { events } = await thread.runStreamed(prompt);
  for await (const event of events) {
    yield event;
  }
}

export function formatCodexResult(result: CodexResult): string {
  const parts: string[] = [];

  if (result.response) {
    parts.push(`## Codex Response\n${result.response}`);
  }

  const commands = result.items.filter(
    (i): i is CommandExecutionItem => i.type === "command_execution",
  );
  if (commands.length > 0) {
    parts.push("## Commands Executed");
    for (const cmd of commands) {
      parts.push(
        `\`\`\`\n$ ${cmd.command}\n${cmd.aggregated_output}\n(exit: ${cmd.exit_code ?? "?"})\n\`\`\``,
      );
    }
  }

  const fileChanges = result.items.filter(
    (i): i is FileChangeItem => i.type === "file_change",
  );
  if (fileChanges.length > 0) {
    parts.push("## File Changes");
    for (const fc of fileChanges) {
      for (const change of fc.changes) {
        parts.push(`- **${change.kind}**: ${change.path}`);
      }
    }
  }

  const messages = result.items.filter(
    (i): i is AgentMessageItem => i.type === "agent_message",
  );
  if (messages.length > 0 && !result.response) {
    parts.push("## Agent Messages");
    for (const msg of messages) {
      parts.push(msg.text);
    }
  }

  if (result.usage) {
    parts.push(
      `\n---\n*Tokens: ${result.usage.input_tokens} in / ${result.usage.output_tokens} out*`,
    );
  }

  return parts.join("\n\n");
}
