const { EventEmitter } = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert');

const { CodexCliProvider, buildCodexPrompt, codexExecArgs } = require('../src/llm/codexCli');

test('buildCodexPrompt: system and recent chat are embedded for Codex OAuth CLI', () => {
  const prompt = buildCodexPrompt({
    system: 'custom-system',
    history: [
      { role: 'user', text: '안녕' },
      { role: 'assistant', text: '반갑다냥' },
      { role: 'user', text: '내 이름 뭐였지?' },
    ],
  });
  assert.match(prompt, /custom-system/);
  assert.match(prompt, /이전 대화/);
  assert.match(prompt, /나: 안녕/);
  assert.match(prompt, /지금 질문: 내 이름 뭐였지\?/);
  assert.match(prompt, /Do not run shell commands/);
});

test('codexExecArgs: uses ephemeral read-only Codex exec with output file', () => {
  const args = codexExecArgs({ model: 'gpt-5.5', cwd: '/tmp', outFile: '/tmp/out.txt', prompt: 'hi' });
  assert.deepEqual(args.slice(0, 2), ['exec', '--ignore-user-config']);
  assert.ok(args.includes('--ephemeral'));
  assert.ok(args.includes('read-only'));
  assert.ok(args.includes('--output-last-message'));
  assert.ok(args.includes('/tmp/out.txt'));
  assert.ok(args.includes('--model'));
  assert.equal(args[args.length - 1], 'hi');
});

test('CodexCliProvider.chat: spawns codex and reads final message file', async () => {
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'openneko-codex-test-'));
  let captured = null;
  const spawnImpl = (_bin, args) => {
    captured = args;
    const child = new EventEmitter();
    child.stdout = new EventEmitter();
    child.stderr = new EventEmitter();
    child.kill = () => { child.killed = true; };
    const outFile = args[args.indexOf('--output-last-message') + 1];
    process.nextTick(() => {
      fs.writeFileSync(outFile, '응답이다냥');
      child.emit('close', 0);
    });
    return child;
  };
  const p = new CodexCliProvider({ spawnImpl, tmpDir: tmpRoot, model: 'gpt-5.5' });
  const r = await p.chat({ history: [{ role: 'user', text: '안녕' }], system: 'sys' });
  assert.equal(r.text, '응답이다냥');
  assert.ok(captured.includes('--model'));
  fs.rmSync(tmpRoot, { recursive: true, force: true });
});
