const { spawn } = require('node:child_process');

// 같은 LAN의 _openneko._tcp 광고+탐색. 자기 자신(myId)은 onUp에서 제외.
function startDiscovery({ port, txt, onUp, onDown }) {
  const myId = txt.id;

  if (process.platform === 'darwin') {
    return startDiscoveryDarwin({ port, txt, myId, onUp, onDown });
  } else {
    return startDiscoveryBonjour({ port, txt, myId, onUp, onDown });
  }
}

// ── darwin: dns-sd CLI implementation ─────────────────────────────────────────

function startDiscoveryDarwin({ port, txt, myId, onUp, onDown }) {
  const instanceName = `openneko-${myId}`;

  // 1. ADVERTISE: dns-sd -R <name> _openneko._tcp local <port> key=val ...
  const advertiseArgs = [
    '-R', instanceName,
    '_openneko._tcp', 'local',
    String(port),
    `id=${txt.id}`,
    `name=${txt.name}`,
    `skin=${txt.skin}`,
    `v=${txt.v}`,
  ];
  const advertiseProc = spawn('dns-sd', advertiseArgs, { stdio: 'ignore' });
  advertiseProc.on('error', (err) => {
    console.error('[discovery] advertise error:', err.message);
  });

  // tracking: instanceName → { id, resolveProc }
  const tracked = new Map();

  // 2. BROWSE: dns-sd -B _openneko._tcp local
  const browseProc = spawn('dns-sd', ['-B', '_openneko._tcp', 'local'], { stdio: ['ignore', 'pipe', 'ignore'] });
  browseProc.on('error', (err) => {
    console.error('[discovery] browse error:', err.message);
  });

  let browseBuffer = '';
  browseProc.stdout.on('data', (chunk) => {
    browseBuffer += chunk.toString();
    const lines = browseBuffer.split('\n');
    browseBuffer = lines.pop(); // keep incomplete last line
    for (const line of lines) {
      handleBrowseLine(line.trim());
    }
  });

  function handleBrowseLine(line) {
    // Match data lines: Add/Rmv  <flags>  <if>  local.  _openneko._tcp.  <instanceName>
    const m = line.match(/\b(Add|Rmv)\b\s+\d+\s+\d+\s+local\.\s+_openneko\._tcp\.\s+(.+?)\s*$/);
    if (!m) return;
    const action = m[1];
    const name = m[2].trim();

    if (action === 'Add') {
      // Skip self
      if (name === instanceName) return;
      // Skip if already tracked (duplicate Add lines can appear)
      if (tracked.has(name)) return;

      // 3. RESOLVE: dns-sd -L <instanceName> _openneko._tcp local
      tracked.set(name, { id: null, resolveProc: null });
      const resolveProc = spawn('dns-sd', ['-L', name, '_openneko._tcp', 'local'], {
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      resolveProc.on('error', (err) => {
        console.error('[discovery] resolve error:', err.message);
      });

      const entry = tracked.get(name);
      entry.resolveProc = resolveProc;
      let resolved = false;
      let resolvedHost = null;
      let resolvedPort = null;

      let resolveBuffer = '';
      resolveProc.stdout.on('data', (chunk) => {
        resolveBuffer += chunk.toString();
        const rlines = resolveBuffer.split('\n');
        resolveBuffer = rlines.pop();
        for (const rline of rlines) {
          handleResolveLine(rline);
        }
      });

      function handleResolveLine(rline) {
        if (resolved) return;

        // Parse host+port: "... can be reached at somehost.local.:48800 ..."
        const hostMatch = rline.match(/can be reached at\s+(\S+?):(\d+)/);
        if (hostMatch) {
          resolvedHost = hostMatch[1].replace(/\.$/, ''); // strip trailing dot
          resolvedPort = Number(hostMatch[2]);
          return;
        }

        // Parse TXT record line (indented key=value pairs)
        // The TXT line starts with whitespace and contains key=val pairs
        if (/^\s+\S+=/.test(rline) && resolvedHost !== null) {
          const txtObj = parseTxtLine(rline.trim());
          if (txtObj.id && txtObj.id !== myId) {
            resolved = true;
            const trackedEntry = tracked.get(name);
            if (trackedEntry) {
              trackedEntry.id = txtObj.id;
            }
            onUp({ host: resolvedHost, port: resolvedPort, txt: txtObj });
            // Kill resolve proc — we only need the first result
            try { resolveProc.kill(); } catch { /* noop */ }
          }
        }
      }
    } else if (action === 'Rmv') {
      const entry = tracked.get(name);
      if (entry) {
        // Kill any pending resolve proc
        if (entry.resolveProc) {
          try { entry.resolveProc.kill(); } catch { /* noop */ }
        }
        tracked.delete(name);
        if (entry.id) {
          onDown(entry.id);
        }
      }
    }
  }

  return {
    stop() {
      try { advertiseProc.kill(); } catch { /* noop */ }
      try { browseProc.kill(); } catch { /* noop */ }
      for (const entry of tracked.values()) {
        if (entry.resolveProc) {
          try { entry.resolveProc.kill(); } catch { /* noop */ }
        }
      }
      tracked.clear();
    },
  };
}

// Parse a TXT record line like: "id=ABC123 name=경수냥 skin=black v=1"
function parseTxtLine(line) {
  const result = {};
  // Split on spaces between key=value pairs; values may contain spaces
  // Use a greedy split: find key= tokens
  const tokenRe = /(\w+)=([^\s=]+(?:\s+(?!\w+=)[^\s=]+)*)/g;
  let m;
  while ((m = tokenRe.exec(line)) !== null) {
    result[m[1]] = m[2].trim();
  }
  return result;
}

// ── non-darwin: bonjour-service fallback ──────────────────────────────────────

function startDiscoveryBonjour({ port, txt, myId, onUp, onDown }) {
  const { Bonjour } = require('bonjour-service');
  const bonjour = new Bonjour();
  const service = bonjour.publish({ name: `openneko-${myId}`, type: 'openneko', port, txt });
  const browser = bonjour.find({ type: 'openneko' }, (svc) => {
    const t = svc.txt || {};
    if (!t.id || t.id === myId) return; // 자기 자신/식별불가 무시
    const host = (svc.referer && svc.referer.address) || (svc.addresses && svc.addresses[0]);
    if (host) onUp({ host, port: svc.port, txt: t });
  });
  browser.on('down', (svc) => {
    const t = (svc && svc.txt) || {};
    if (t.id && t.id !== myId) onDown(t.id);
  });
  return {
    stop() {
      try { browser.stop(); } catch { /* noop */ }
      try { service.stop(); } catch { /* noop */ }
      try { bonjour.destroy(); } catch { /* noop */ }
    },
  };
}

module.exports = { startDiscovery };
