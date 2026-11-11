// RAMBO login page: solve the proof-of-work puzzle in a Web Worker while
// the person types, then let the form be sent.  The server demands the
// solved puzzle before it checks a password.
//
// Every way out ends with a visible message -- solved, timed out, failed,
// or not possible in this browser -- so the page can never sit at
// "working" for ever. The result is also written to data-pow-* attributes
// on the form, where the solving times can be read.
"use strict";
(function () {
  var form = document.getElementById("login");
  if (!form) {
    return;
  }
  var d = form.dataset;
  var status = document.getElementById("pow-status");
  var nonce = document.getElementById("pow-nonce");
  var button = document.getElementById("login-submit");

  function show(text, isError) {
    status.textContent = text;
    status.className = isError ? "error" : "info";
    status.hidden = false;
  }

  function finish(result, text, isError) {
    d.powResult = result;
    show(text, isError);
  }

  button.disabled = true;
  if (!window.Worker || !window.crypto || !window.crypto.subtle) {
    finish("unsupported", d.msgUnsupported, true);
    return;
  }

  var worker;
  try {
    worker = new Worker("/pow-worker.js");
  } catch (e) {
    finish("unsupported", d.msgUnsupported, true);
    return;
  }
  show(d.msgWorking, false);
  var started = performance.now();
  var timer = setTimeout(function () {
    worker.terminate();
    d.powMs = String(Math.round(performance.now() - started));
    finish("timeout", d.msgTimeout, true);
  }, Number(d.powTimeout));

  worker.onmessage = function (e) {
    clearTimeout(timer);
    worker.terminate();
    if (e.data.error) {
      finish("error:" + e.data.error, d.msgUnsupported, true);
      return;
    }
    nonce.value = e.data.nonce;
    d.powMs = String(Math.round(performance.now() - started));
    d.powTries = String(e.data.tries);
    button.disabled = false;
    finish("ok", d.msgDone, false);
  };
  worker.onerror = function (e) {
    clearTimeout(timer);
    worker.terminate();
    if (e && e.preventDefault) {
      e.preventDefault();
    }
    finish("error:worker", d.msgUnsupported, true);
  };
  worker.postMessage({ token: d.powToken, bits: Number(d.powBits), batch: Number(d.powBatch) });
})();
