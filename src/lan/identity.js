function ensurePeerId(stored, genId) {
  return (typeof stored === 'string' && stored) ? stored : genId();
}
function displayName(profileName, fallback) {
  const n = (typeof profileName === 'string' ? profileName : '').trim();
  return (n || fallback).slice(0, 64);
}
module.exports = { ensurePeerId, displayName };
