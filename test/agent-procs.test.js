const test = require('node:test');
const assert = require('node:assert/strict');
const { detectAgentProcessCpu } = require('../src/agentProcs');

test('detectAgentProcessCpu: recognizes common AI agent services', () => {
  const cpu = detectAgentProcessCpu(`
    11.5 /Applications/Cursor.app/Contents/MacOS/Cursor
    12.0 /opt/homebrew/bin/claude -p hello
    13.0 /opt/homebrew/bin/codex exec prompt
    14.0 /Applications/Codex.app/Contents/MacOS/Codex
    15.0 /Applications/Antigravity.app/Contents/MacOS/Antigravity
    16.0 /opt/homebrew/bin/gemini -p hello
    17.0 /Applications/Kiro.app/Contents/MacOS/Kiro
  `);

  assert.deepEqual(cpu, {
    cursor: 11.5,
    claude: 12,
    'codex-cli': 13,
    'codex-app': 14,
    antigravity: 15,
    gemini: 16,
    kiro: 17,
  });
});

test('detectAgentProcessCpu: recognizes npm package shims and helper processes', () => {
  const cpu = detectAgentProcessCpu(`
    4.5 /Applications/Cursor.app/Contents/Frameworks/Cursor Helper.app/Contents/MacOS/Cursor Helper
    7.5 node /usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js
    8.5 node /usr/local/lib/node_modules/@openai/codex/bin/codex.js
    9.5 node /usr/local/lib/node_modules/@google/gemini-cli/dist/index.js
  `);

  assert.equal(cpu.cursor, 4.5);
  assert.equal(cpu.claude, 7.5);
  assert.equal(cpu['codex-cli'], 8.5);
  assert.equal(cpu.gemini, 9.5);
});

test('detectAgentProcessCpu: keeps max CPU per source and ignores invalid rows', () => {
  const cpu = detectAgentProcessCpu(`
    nope /Applications/Cursor.app/Contents/MacOS/Cursor
    2.0 /opt/homebrew/bin/codex exec prompt
    18.0 /tmp/node /some/path/@openai/codex/bin/codex.js
    1.0 unrelated process
  `);

  assert.deepEqual(cpu, { 'codex-cli': 18 });
});
