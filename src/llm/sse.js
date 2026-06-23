// SSE 스트림 파서. feed(문자열 청크) → 완성된 data: 라인 페이로드 배열. 부분 라인은 내부 버퍼에 보관.
function createSSEParser() {
  let buf = '';
  return function feed(chunk) {
    buf += chunk;
    const out = [];
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i).replace(/\r$/, '');
      buf = buf.slice(i + 1);
      if (line.startsWith('data:')) {
        const d = line.slice(5).trim();
        if (d) out.push(d);
      }
    }
    return out;
  };
}
module.exports = { createSSEParser };
