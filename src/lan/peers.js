// src/lan/peers.js
// 피어 레지스트리 — 불변 plain object {[id]: {id,name,skin,presence,lastSeen}}.
function addOrUpdate(map, peer) {
  const prev = map[peer.id] || { presence: 'idle' };
  return { ...map, [peer.id]: { ...prev, ...peer } };
}
function remove(map, id) {
  if (!(id in map)) return map;
  const out = { ...map };
  delete out[id];
  return out;
}
function touch(map, id, lastSeen) {
  if (!(id in map)) return map;
  return { ...map, [id]: { ...map[id], lastSeen } };
}
function setPresence(map, id, state) {
  if (!(id in map)) return map;
  return { ...map, [id]: { ...map[id], presence: state } };
}
function prune(map, now, ttlMs) {
  const out = {};
  for (const id of Object.keys(map)) {
    if (now - (map[id].lastSeen || 0) <= ttlMs) out[id] = map[id];
  }
  return out;
}
function list(map) {
  return Object.keys(map).sort().map((id) => map[id]);
}
module.exports = { addOrUpdate, remove, touch, setPresence, prune, list };
