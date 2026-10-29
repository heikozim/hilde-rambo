# Part of rambo.
#
# SPDX-FileCopyrightText: 2026 Heiko Zimmermann
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Passkeys end to end against a rambo serving over HTTP, a browser played
# with http.client and the authenticator of Wolly (passkey-authenticator.py,
# CBOR and the signature by openssl).  The mode add signs alice in with
# password and code, adds a passkey on the account page and signs in with
# it; the mode revoked checks that the passkey no longer signs anybody in.
# Every check prints step=<name> rc=<got> want=<wanted>; the last line
# counts them, and the exit status is 0 only when all are as wanted.
#
#     python3 -I passkey-e2e.py add|revoked PORT EXPECTED.JSON AUTHENTICATOR KEY.PEM
import base64
import hashlib
import hmac
import http.client
import json
import re
import struct
import subprocess
import sys
import time
import urllib.parse

mode, port, expected_path, authenticator, key = sys.argv[1:6]
expected = json.load(open(expected_path))
issuer = expected["issuer"]
parsed = urllib.parse.urlsplit(issuer)
origin = "%s://%s" % (parsed.scheme, parsed.netloc)
party = parsed.hostname
good = 0
bad = 0


def check(name, got, want):
    global good, bad
    print("step=%s rc=%s want=%s" % (name, got, want))
    if str(got) == str(want):
        good += 1
    else:
        bad += 1


class Browser:
    def __init__(self):
        self.jar = {}

    def send(self, verb, path, form=None):
        conn = http.client.HTTPConnection("127.0.0.1", int(port), timeout=30)
        headers = {}
        if self.jar:
            headers["Cookie"] = "; ".join("%s=%s" % kv for kv in self.jar.items())
        body = None
        if form is not None:
            body = urllib.parse.urlencode(form)
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        conn.request(verb, path, body=body, headers=headers)
        r = conn.getresponse()
        text = r.read().decode("utf-8", "replace")
        for name, value in r.getheaders():
            if name.lower() != "set-cookie":
                continue
            pair = value.split(";", 1)[0]
            cname, _, cvalue = pair.partition("=")
            if "max-age=0" in value.lower() or cvalue == "":
                self.jar.pop(cname, None)
            else:
                self.jar[cname] = cvalue
        conn.close()
        return r.status, r.getheader("Location", ""), text


def attribute(page, name):
    m = re.search(r'%s="([^"]*)"' % re.escape(name), page)
    return m.group(1) if m else ""


def csrf_of(page, action):
    m = re.search(r'action="%s"[^>]*>\s*<input type="hidden" name="csrf" value="([^"]*)"' % re.escape(action), page)
    return m.group(1) if m else ""


def solve(token, bits):
    n = 0
    while True:
        digest = hashlib.sha256(("%s:%d" % (token, n)).encode()).digest()
        zeros = 0
        for b in digest:
            if b == 0:
                zeros += 8
                continue
            zeros += 8 - b.bit_length()
            break
        if zeros >= bits:
            return str(n)
        n += 1


def code_at(secret, at):
    raw = base64.b32decode(secret.upper() + "=" * (-len(secret) % 8))
    mac = hmac.new(raw, struct.pack(">Q", at // 30), hashlib.sha1).digest()
    o = mac[-1] & 15
    return "%06d" % ((struct.unpack(">I", mac[o:o + 4])[0] & 0x7FFFFFFF) % 1000000)


def authenticate(*args):
    out = subprocess.run(["python3", "-I", authenticator] + list(args), check=True, capture_output=True, text=True).stdout
    return dict(urllib.parse.parse_qsl(out.strip()))


def login_page(browser):
    status, location, _ = browser.send("GET", "/login")
    req = urllib.parse.parse_qs(urllib.parse.urlsplit(location).query).get("req", [""])[0]
    status, _, page = browser.send("GET", "/login?req=" + urllib.parse.quote(req))
    return req, status, page


def passkey_login(browser, req, page, counter, where):
    form = authenticate("get", key, attribute(page, "data-challenge"), where, party, str(counter))
    form["req"] = req
    return browser.send("POST", "/login/passkey", form)


def add():
    alice = Browser()
    req, status, page = login_page(alice)
    check("login-page", status, 200)
    check("login-page-has-passkey", 1 if attribute(page, "data-challenge") else 0, 1)
    check("login-page-party", attribute(page, "data-party"), party)
    nonce = solve(attribute(page, "data-pow-token"), int(attribute(page, "data-pow-bits")))
    used = int(time.time()) // 30
    status, location, _ = alice.send("POST", "/login", {
        "req": req, "pow": attribute(page, "data-pow-token"), "pow_nonce": nonce,
        "email": expected["alice_email"], "password": expected["alice_password"],
        "code": code_at(expected["alice_totp_secret"], int(time.time()))})
    check("password-login", status, 302)
    status, _, page = alice.send("GET", "/account")
    check("account-page", status, 200)
    check("account-has-no-passkey", 1 if "passkey/remove" in page else 0, 0)
    begin = csrf_of(page, "/account/passkey")
    status, _, _ = alice.send("POST", "/account/passkey", {"csrf": begin, "old": "wrong password", "code": "000000"})
    check("add-without-password", status, 400)
    status, _, _ = alice.send("POST", "/account/passkey", {"csrf": "forged", "old": expected["alice_password"], "code": "000000"})
    check("add-forged-token", status, 403)
    # A code counts once: the one of the login is spent, wait for the next.
    while int(time.time()) // 30 == used:
        time.sleep(1)
    status, _, page = alice.send("POST", "/account/passkey", {
        "csrf": begin, "old": expected["alice_password"], "code": code_at(expected["alice_totp_secret"], int(time.time()))})
    check("add-begins", status, 200)
    check("add-party", attribute(page, "data-party"), party)
    check("add-user", attribute(page, "data-user"), base64.urlsafe_b64encode(expected["alice_id"].encode()).rstrip(b"=").decode())
    challenge = attribute(page, "data-challenge")
    form = authenticate("create", key, challenge, origin, party)
    m = re.search(r'id="passkey-add"[\s\S]*?name="csrf" value="([^"]*)"', page)
    form["csrf"] = m.group(1) if m else ""
    form["label"] = "Laptop"
    status, location, _ = alice.send("POST", "/account/passkey/add", form)
    check("add-kept", status, 303)
    check("add-kept-location", location, "/account?done=passkey")
    status, _, _ = alice.send("POST", "/account/passkey/add", form)
    check("add-again-challenge-spent", status, 400)
    status, _, page = alice.send("GET", "/account")
    check("account-lists-passkey", 1 if ("Laptop" in page and "EBESExQVFhcYGRobHB0eHw" in page) else 0, 1)
    rename = csrf_of(page, "/account/passkey/rename")
    status, location, _ = alice.send("POST", "/account/passkey/rename",
                                     {"csrf": rename, "credential": "EBESExQVFhcYGRobHB0eHw", "label": "Notebook"})
    check("rename", status, 303)
    status, _, _ = alice.send("POST", "/account/passkey/rename", {"csrf": rename, "credential": "AAAA", "label": "x"})
    check("rename-unknown", status, 404)
    status, _, page = alice.send("GET", "/account")
    check("account-shows-new-name", 1 if "Notebook" in page else 0, 1)

    stranger = Browser()
    req, status, page = login_page(stranger)
    status, _, _ = passkey_login(stranger, req, page, 1, "https://evil.example")
    check("passkey-other-origin", status, 401)
    status, _, page = stranger.send("GET", "/login?req=" + urllib.parse.quote(req))
    status, location, _ = passkey_login(stranger, req, page, 1, origin)
    check("passkey-login", status, 302)
    check("passkey-login-session", 1 if "__Host-rambo" in stranger.jar else 0, 1)
    status, _, page = stranger.send("GET", "/account")
    check("passkey-session-account", 1 if (status == 200 and expected["alice_id"] in page) else 0, 1)
    again = Browser()
    req, status, page = login_page(again)
    status, _, _ = passkey_login(again, req, page, 1, origin)
    check("passkey-same-counter-replayed", status, 401)
    status, _, page = again.send("GET", "/login?req=" + urllib.parse.quote(req))
    status, _, _ = passkey_login(again, req, page, 2, origin)
    check("passkey-counter-2", status, 302)


def revoked():
    browser = Browser()
    req, status, page = login_page(browser)
    status, _, _ = passkey_login(browser, req, page, 3, origin)
    check("revoked-passkey-refused", status, 401)


add() if mode == "add" else revoked()
print("passkey-e2e: %d as wanted, %d not" % (good, bad))
sys.exit(0 if bad == 0 else 1)
