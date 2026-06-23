const AGENT_PROCESS_DEFINITIONS = [
  {
    source: 'cursor',
    label: 'Cursor',
    re: /(^|\/)(Cursor|cursor)(\.app|\s|$)|Cursor Helper|cursor-agent/i,
  },
  {
    source: 'claude',
    label: 'Claude Code',
    re: /(^|\/)claude(\s|$|-)|@anthropic-ai\/claude-code|claude-code/i,
  },
  {
    source: 'codex-cli',
    label: 'Codex CLI',
    re: /(^|\/)codex(\s|$|-)|@openai\/codex|codex-cli/,
  },
  {
    source: 'codex-app',
    label: 'Codex App',
    re: /(^|\/)Codex(\.app|\s|$)|Codex Helper/,
  },
  {
    source: 'antigravity',
    label: 'Antigravity',
    re: /(^|\/)Antigravity(\.app|\s|$)|antigravity/i,
  },
  {
    source: 'gemini',
    label: 'Gemini',
    re: /(^|\/)gemini(\s|$|-)|@google\/gemini-cli|gemini-cli/i,
  },
  {
    source: 'kiro',
    label: 'Kiro',
    re: /(^|\/)kiro(\s|$)|Kiro\.app|Kiro Helper/i,
  },
];

function detectAgentProcessCpu(psOutput, definitions = AGENT_PROCESS_DEFINITIONS) {
  const cpu = {};
  for (const line of String(psOutput || '').split('\n')) {
    const m = line.trim().match(/^([\d.]+)\s+(.+)$/);
    if (!m) continue;
    const usage = parseFloat(m[1]);
    if (!Number.isFinite(usage)) continue;
    const args = m[2];
    for (const agent of definitions) {
      if (agent.re.test(args)) {
        cpu[agent.source] = Math.max(cpu[agent.source] || 0, usage);
      }
    }
  }
  return cpu;
}

module.exports = { AGENT_PROCESS_DEFINITIONS, detectAgentProcessCpu };
