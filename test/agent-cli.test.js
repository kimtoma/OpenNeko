const { EventEmitter } = require('node:events');
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  ClaudeCliProvider,
  GeminiCliProvider,
  buildInlinePrompt,
  buildClaudeSystem,
  claudePrintArgs,
  geminiPromptArgs,
} = require('../src/llm/agentCli');

function fakeSpawnWithStdout(text, capture) {
  return (bin, args, opts) => {
    capture.bin = bin;
    capture.args = args;
    capture.opts = opts;
    const child = new EventEmitter();
    child.stdout = new EventEmitter();
    child.stderr = new EventEmitter();
    child.kill = () => { child.killed = true; };
    process.nextTick(() => {
      child.stdout.emit('data', text);
      child.emit('close', 0);
    });
    return child;
  };
}

test('buildInlinePrompt: embeds openNeko system and recent chat for agent CLIs', () => {
  const prompt = buildInlinePrompt({
    service: 'Gemini CLI',
    system: 'custom-system',
    history: [
      { role: 'user', text: '안녕' },
      { role: 'assistant', text: '반갑다냥' },
      { role: 'user', text: '내 이름 뭐였지?' },
    ],
  });

  assert.match(prompt, /custom-system/);
  assert.match(prompt, /Gemini CLI/);
  assert.match(prompt, /Do not run shell commands/);
  assert.match(prompt, /이전 대화/);
  assert.match(prompt, /지금 질문: 내 이름 뭐였지\?/);
});

test('claudePrintArgs: disables tools and uses non-persistent print mode', () => {
  const args = claudePrintArgs({ model: 'sonnet', system: 'sys', prompt: 'hi' });
  assert.deepEqual(args.slice(0, 2), ['--model', 'sonnet']);
  assert.ok(args.includes('--safe-mode'));
  assert.ok(args.includes('--no-session-persistence'));
  assert.ok(args.includes('--tools'));
  assert.equal(args[args.indexOf('--tools') + 1], '');
  assert.equal(args[args.indexOf('--system-prompt') + 1], 'sys');
  assert.equal(args[args.length - 2], '-p');
  assert.equal(args[args.length - 1], 'hi');
});

test('geminiPromptArgs: uses headless prompt mode with plan approval', () => {
  const args = geminiPromptArgs({ model: 'gemini-test', prompt: 'hi' });
  assert.deepEqual(args.slice(0, 2), ['--model', 'gemini-test']);
  assert.ok(args.includes('--prompt'));
  assert.equal(args[args.indexOf('--prompt') + 1], 'hi');
  assert.ok(args.includes('--approval-mode'));
  assert.equal(args[args.indexOf('--approval-mode') + 1], 'plan');
});

test('ClaudeCliProvider.chat: spawns claude and returns stdout', async () => {
  const captured = {};
  const p = new ClaudeCliProvider({ spawnImpl: fakeSpawnWithStdout('응답이다냥\n', captured), model: 'sonnet' });
  const r = await p.chat({ history: [{ role: 'user', text: '안녕' }], system: 'sys' });
  assert.equal(r.text, '응답이다냥');
  assert.equal(captured.bin, 'claude');
  assert.ok(captured.args.includes('--system-prompt'));
  assert.match(buildClaudeSystem({ system: 'sys' }), /openNeko/);
});

test('GeminiCliProvider.chat: spawns gemini and returns stdout', async () => {
  const captured = {};
  const p = new GeminiCliProvider({ spawnImpl: fakeSpawnWithStdout('응답이다냥\n', captured), model: 'gemini-test' });
  const r = await p.chat({ history: [{ role: 'user', text: '안녕' }], system: 'sys' });
  assert.equal(r.text, '응답이다냥');
  assert.equal(captured.bin, 'gemini');
  assert.ok(captured.args.includes('--prompt'));
  assert.ok(captured.args.includes('--approval-mode'));
});
