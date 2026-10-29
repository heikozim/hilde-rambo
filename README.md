# rambo

RAMBO, a sign-in service: an OpenID provider for a fixed set of first-party
clients, written in Hilde on the web framework Wolly.  It replaces an
earlier provider written in Go without a change for its clients, and adds
passkeys.

This repository carries the programme, its tests and test data, the files
for a deployment and the documentation for the user.  Issues, questions
and patches go to code@heiko-zimmermann.com.  It is written in
Hilde, https://github.com/heikozim/hilde, on Wolly,
https://github.com/heikozim/hilde-wolly, and runs behind the web server
Hiawatha.

## What it does

- OpenID Connect: discovery, the key set, `/authorize` with PKCE (S256) and a
  nonce, `/token` with authorization codes, refresh tokens rotated in
  families and client credentials, `/logout`; ID tokens signed with
  ML-DSA-44 or the composite ML-DSA-44-Ed25519 only; the mark RS256 the
  earlier provider set on a client is cleared when its database is taken over.
- The pages a person signs in on: e-mail address, a proof of work, the
  password and a code of an authenticator app, or a passkey; the account
  page with password, second factor, sessions and devices.
- Secrets, sessions, codes and refresh tokens are kept only as SHA-256; the
  keys and the pepper in a vault.
- The command `rambo`: `serve` (FastCGI behind Hiawatha, or HTTP on the
  loopback for development), `setup` (the vault), `account`, `client`,
  `migrate` (a database of the earlier provider taken over), `version`, `info`
  and `sandbox`.  On OpenBSD it runs under pledge and unveil, on Linux under
  Landlock and seccomp.

## Building and testing

The checks are in the `Makefile`: `make check-all` runs every one, and a
check that could not run ends with exit 9.  The builds and tests run in a
container image with the Hilde compiler and its standard library on a
build host that `scripts/remote.sh` reaches by ssh; `scripts/remote.env.example`
names the settings (`RAMBO_HOST`, `RAMBO_SSH_USER`, `RAMBO_SSH_PORT`,
`RAMBO_REMOTE_DIR`).  `scripts/run.sh` sends this tree and the Wolly tree
it builds on (`WOLLY_TREE`) to the container and runs one script of
`scripts/image/` there; `scripts/wolly-modules.txt` lists the modules of
Wolly the checks take with rambo's own.

## Documents

- `deploy/` -- the rc.d script and the update script of rambo on OpenBSD and
  an example of the Hiawatha configuration
- `CHANGELOG` -- the releases, the newest first
- `LICENSE` -- the Apache License 2.0 with LLVM Exceptions

## License

Copyright (c) 2026 Heiko Zimmermann <code@heiko-zimmermann.com>

rambo is licensed under the Apache License 2.0 with LLVM exception; see LICENSE.

## Checking a release

A release is an archive `rambo-X.Y.Z.tar.gz` of the tree at the tag vX.Y.Z,
its signature made with signify and a file SHA256 with the checksums of
both, on the release page of this repository.  The public key is
`rambo-0.pub` in the root of the repository; `VERIFY.md` of a release says
how to check it:

```
signify -V -p rambo-0.pub -x rambo-X.Y.Z.tar.gz.sig -m rambo-X.Y.Z.tar.gz
```
