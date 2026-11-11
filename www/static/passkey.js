// Part of rambo.
//
// SPDX-FileCopyrightText: 2026 Heiko Zimmermann
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// RAMBO passkeys: on the login page ask the authenticator for a passkey of
// this site, on the page that makes one ask it for a new credential.  The
// challenge, the relying party and the user come from data attributes the
// server wrote; the answer goes back in hidden fields, base64url without
// padding, and the form is sent.  Every way out ends with a message.
"use strict";
(function () {
  var login = document.getElementById("passkey-login");
  var add = document.getElementById("passkey-add");
  var form = login || add;
  if (!form) {
    return;
  }
  var d = form.dataset;
  var status = document.getElementById("passkey-status");
  var button = document.getElementById(login ? "passkey-start" : "passkey-create");

  function show(text, isError) {
    status.textContent = text;
    status.className = isError ? "error" : "info";
    status.hidden = false;
  }

  function bytes(text) {
    var s = text.replace(/-/g, "+").replace(/_/g, "/");
    while (s.length % 4) {
      s += "=";
    }
    var raw = atob(s);
    var out = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) {
      out[i] = raw.charCodeAt(i);
    }
    return out;
  }

  function text(buffer) {
    var b = new Uint8Array(buffer);
    var s = "";
    for (var i = 0; i < b.length; i++) {
      s += String.fromCharCode(b[i]);
    }
    return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }

  function put(name, value) {
    form.elements[name].value = value;
  }

  if (!window.PublicKeyCredential || !navigator.credentials) {
    button.disabled = true;
    show(d.msgUnsupported, true);
    return;
  }

  function signIn() {
    return navigator.credentials.get({
      publicKey: {
        challenge: bytes(d.challenge),
        rpId: d.party,
        userVerification: "required",
        timeout: 300000
      }
    }).then(function (credential) {
      var r = credential.response;
      put("credential", text(credential.rawId));
      put("clientData", text(r.clientDataJSON));
      put("authenticatorData", text(r.authenticatorData));
      put("signature", text(r.signature));
    });
  }

  function create() {
    var exclude = d.exclude ? d.exclude.split(" ") : [];
    return navigator.credentials.create({
      publicKey: {
        challenge: bytes(d.challenge),
        rp: { id: d.party, name: "RAMBO" },
        user: { id: bytes(d.user), name: d.userName, displayName: d.display },
        pubKeyCredParams: [{ type: "public-key", alg: -7 }, { type: "public-key", alg: -8 }],
        authenticatorSelection: { residentKey: "required", requireResidentKey: true, userVerification: "required" },
        attestation: "none",
        excludeCredentials: exclude.map(function (id) {
          return { type: "public-key", id: bytes(id) };
        }),
        timeout: 300000
      }
    }).then(function (credential) {
      put("clientData", text(credential.response.clientDataJSON));
      put("attestation", text(credential.response.attestationObject));
    });
  }

  button.addEventListener("click", function () {
    button.disabled = true;
    show(d.msgWorking, false);
    (login ? signIn() : create()).then(function () {
      form.submit();
    }, function () {
      button.disabled = false;
      show(d.msgCancelled, true);
    });
  });
})();
