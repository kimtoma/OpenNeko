// LAN 피어 링크 — WebSocket 서버 + 연결
const { WebSocketServer, WebSocket } = require('ws');
const { parse, encode } = require('./protocol');

// myId < peerId 인 쪽만 connect(중복연결 방지). 서버는 들어오는 연결을 hello로 id 바인딩.
function createLink({ myId, getHello, onMessage, onPeerClosed }) {
  const sockets = new Map(); // id -> ws
  let wss = null;

  function bind(ws, id) {
    if (!id) return;
    const old = sockets.get(id);
    if (old && old !== ws) { try { old.close(); } catch { /* noop */ } }
    sockets.set(id, ws);
    ws._peerId = id;
  }
  function wire(ws, knownId) {
    if (knownId) bind(ws, knownId);
    ws.on('message', (data) => {
      const msg = parse(String(data));
      if (!msg) return;
      if (msg.t === 'hello') {
        bind(ws, msg.id);
        if (!ws._outgoing && !ws._helloSent) {
          ws._helloSent = true;
          try { ws.send(encode(getHello())); } catch { /* noop */ }
        }
      }
      const id = ws._peerId || (msg.t === 'hello' ? msg.id : null);
      if (id) onMessage(id, msg);
    });
    ws.on('close', () => {
      if (ws._peerId && sockets.get(ws._peerId) === ws) {
        sockets.delete(ws._peerId);
        onPeerClosed(ws._peerId);
      }
    });
    ws.on('error', () => { try { ws.close(); } catch { /* noop */ } });
  }

  return {
    listen() {
      return new Promise((resolve, reject) => {
        wss = new WebSocketServer({ host: '0.0.0.0', port: 0, maxPayload: 4096 });
        wss.on('connection', (ws) => wire(ws, null));
        wss.on('listening', () => resolve(wss.address().port));
        wss.on('error', (err) => reject(err));
      });
    },
    connect(id, host, port) {
      if (id <= myId) return;            // 작은 id 쪽만 connect
      if (sockets.has(id)) return;       // 이미 연결됨
      const ws = new WebSocket(`ws://${host}:${port}`);
      ws.on('open', () => { bind(ws, id); ws._outgoing = true; ws._helloSent = true; ws.send(encode(getHello())); });
      wire(ws, id);
    },
    send(id, msg) {
      const ws = sockets.get(id);
      if (ws && ws.readyState === WebSocket.OPEN) { try { ws.send(encode(msg)); } catch { /* noop */ } }
    },
    broadcast(msg) { for (const id of sockets.keys()) this.send(id, msg); },
    close() {
      for (const ws of sockets.values()) { try { ws.close(); } catch { /* noop */ } }
      sockets.clear();
      if (wss) { try { wss.close(); } catch { /* noop */ } wss = null; }
    },
  };
}
module.exports = { createLink };
