import Anthropic from "@anthropic-ai/sdk";

export interface ClaudeResult {
  response: string;
  usage: { input_tokens: number; output_tokens: number } | null;
}

let client: Anthropic | null = null;

function getClient(): Anthropic {
  if (!client) {
    client = new Anthropic();
  }
  return client;
}

export async function runClaudeTask(
  prompt: string,
  options: {
    model?: string;
    systemPrompt?: string;
    maxTokens?: number;
  } = {},
): Promise<ClaudeResult> {
  const anthropic = getClient();

  const message = await anthropic.messages.create({
    model: options.model ?? "claude-sonnet-4-20250514",
    max_tokens: options.maxTokens ?? 4096,
    system: options.systemPrompt ?? "You are a helpful coding assistant.",
    messages: [{ role: "user", content: prompt }],
  });

  const textBlocks = message.content.filter((b) => b.type === "text");
  const response = textBlocks.map((b) => b.text).join("\n");

  return {
    response,
    usage: {
      input_tokens: message.usage.input_tokens,
      output_tokens: message.usage.output_tokens,
    },
  };
}
