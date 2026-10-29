// powkit worker: find a nonce so that SHA-256(token ":" nonce) starts with
// at least `bits` zero bits -- the same puzzle as powkit.Check in Go.
//
// Message in:  {token: string, bits: number, batch: number}
// Message out: {nonce: string, tries: number, ms: number}
//          or: {error: "unsupported" | "failed", detail: string}
//
// crypto.subtle.digest is asynchronous, one promise per hash; the worker
// runs `batch` of them at a time. It never stops by itself: the page ends
// it with terminate() when its time limit is up.
"use strict";

function zeroBits(b) {
  let z = 0;
  for (let i = 0; i < b.length; i++) {
    if (b[i] === 0) {
      z += 8;
      continue;
    }
    return z + Math.clz32(b[i]) - 24;
  }
  return z;
}

self.onmessage = async function (e) {
  const token = String(e.data.token);
  const bits = Number(e.data.bits);
  const batch = Math.max(1, Math.min(4096, Number(e.data.batch) || 256));
  if (!self.crypto || !self.crypto.subtle || typeof TextEncoder === "undefined") {
    self.postMessage({ error: "unsupported", detail: "no WebCrypto in this worker" });
    return;
  }
  const enc = new TextEncoder();
  const prefix = token + ":";
  const t0 = performance.now();
  try {
    for (let n = 0; ; n += batch) {
      const jobs = new Array(batch);
      for (let i = 0; i < batch; i++) {
        jobs[i] = self.crypto.subtle.digest("SHA-256", enc.encode(prefix + (n + i)));
      }
      const sums = await Promise.all(jobs);
      for (let i = 0; i < batch; i++) {
        if (zeroBits(new Uint8Array(sums[i])) >= bits) {
          self.postMessage({ nonce: String(n + i), tries: n + i + 1, ms: performance.now() - t0 });
          return;
        }
      }
    }
  } catch (err) {
    self.postMessage({ error: "failed", detail: String(err) });
  }
};
