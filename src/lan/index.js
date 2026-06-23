const { startDiscovery } = require('./discovery');
const { createLink } = require('./link');
const P = require('./peers');
const { coarsePresence } = require('./protocol');

const PRUNE_MS = 12000;

function createNeighborNet({ myId, getSelf, onEvent }) {
  let peers = {};
  let disc = null, link = null, pruneTimer = null, lastPresence = 'idle';

  function helloMsg() { const s = getSelf(); return { t: 'hello', id: myId, name: s.name, skin: s.skin }; }

  function onMessage(id, msg) {
    const now = Date.now();
    if (msg.t === 'hello') {
      const known = !!peers[id];
      peers = P.addOrUpdate(peers, { id, name: msg.name, skin: msg.skin, lastSeen: now });
      if (!known) {
        onEvent({ type: 'joined', id, name: msg.name, skin: msg.skin });
        link.send(id, { t: 'presence', state: lastPresence }); // 새 피어에 내 현재 상태 알림
      }
    } else if (msg.t === 'presence') {
      peers = P.setPresence(P.touch(peers, id, now), id, msg.state);
      onEvent({ type: 'presence', id, state: msg.state });
    } else if (msg.t === 'wave') {
      onEvent({ type: 'wave', id });
    } else if (msg.t === 'greeting') {
      onEvent({ type: 'greeting', id, key: msg.key });
    } else if (msg.t === 'bye') {
      dropPeer(id);
    }
  }
  function dropPeer(id) {
    if (!peers[id]) return;
    peers = P.remove(peers, id);
    onEvent({ type: 'left', id });
  }

  return {
    async start() {
      link = createLink({ myId, getHello: helloMsg, onMessage, onPeerClosed: dropPeer });
      const port = await link.listen();
      const self = getSelf();
      disc = startDiscovery({
        port,
        txt: { id: myId, name: self.name, skin: self.skin, v: '1' },
        onUp: ({ host, port: p, txt }) => {
          link.connect(txt.id, host, p);          // 작은 id면 연결, 큰 id면 무시(상대가 옴)
        },
        onDown: (id) => dropPeer(id),
      });
      pruneTimer = setInterval(() => {
        const next = P.prune(peers, Date.now(), PRUNE_MS);
        for (const id of Object.keys(peers)) if (!next[id]) onEvent({ type: 'left', id });
        peers = next;
      }, 4000);
    },
    stop() {
      if (pruneTimer) clearInterval(pruneTimer);
      if (link) link.broadcast({ t: 'bye' });
      if (disc) disc.stop();
      if (link) link.close();
      disc = null; link = null; peers = {}; lastPresence = 'idle';
    },
    setPresence(coarse) {
      if (coarse === lastPresence) return;
      lastPresence = coarse;
      if (link) link.broadcast({ t: 'presence', state: coarse });
    },
    sendWave(id) { if (link) link.send(id, { t: 'wave' }); },
    sendGreeting(id, key) { if (link) link.send(id, { t: 'greeting', key }); },
  };
}
module.exports = { createNeighborNet, coarsePresence };
