<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/rambo-wordmark-dark.svg">
  <img src="docs/logo/rambo-wordmark-light.svg" alt="RAMBO" width="310" height="100">
</picture>

RAMBO: Rights, Accounts, Multi-factor, Bearer tokens & OAuth. An OpenID provider with passkeys, written in Hilde on Wolly

Website: https://hilde-lang.org/rambo/

# RAMBO

A sign-in service: an OpenID provider for a fixed set of first-party
clients, written in [Hilde](https://github.com/heikozim/hilde) on
[Wolly](https://github.com/heikozim/hilde-wolly). It runs behind the web
server Hiawatha.

## Features

- **OpenID Connect**: discovery, key set, `/authorize` with PKCE (S256)
  and nonce, `/token` (authorization code, rotating refresh tokens,
  client credentials), `/logout`
- **Post-quantum tokens**: ID tokens signed with ML-DSA-44 or the
  composite ML-DSA-44-Ed25519
- **Sign-in**: password plus authenticator app (TOTP), or passkey;
  proof of work against bots
- **Account page**: password, second factor, sessions and devices
- **Storage**: secrets, sessions, codes and refresh tokens only as
  SHA-256; keys and pepper in an encrypted vault
- **Sandbox**: pledge and unveil on OpenBSD, Landlock and seccomp on Linux

## Quick start

```sh
rambo setup init
rambo account add alice@example.org --name Alice
rambo client add --id lucy --kind web --redirect https://lucy.example.org/cb
rambo serve
```

## Commands

| Command          | Purpose                                                        |
|------------------|----------------------------------------------------------------|
| `rambo serve`    | Run RAMBO (FastCGI behind Hiawatha, or HTTP on loopback)       |
| `rambo setup`    | Manage the vault: `init`, `set`, `get`, `list`, `delete`, `rotate-key`, `rotate-pepper` |
| `rambo account`  | `add`, `list`, `set-email`, `set-name`, `lock`, `unlock`, `reset-password`, `reset-totp`, `reset-passkeys`, `delete` |
| `rambo client`   | `add`, `list`, `limits`, `alg`, `lax`, `disable`, `enable`, `rotate-secret`, `start-url`, `logo`, `set-name` |
| `rambo role`     | `grant`, `revoke`, `list`                                      |
| `rambo session`  | `list`, `end`                                                  |
| `rambo passkey`  | `list`, `revoke`                                               |
| `rambo keys`     | `rotate` the signing keys                                      |
| `rambo migrate`  | Take over the database of the earlier Go provider              |
| `rambo sandbox`  | Print the sandbox profiles                                     |
| `rambo info`     | Print the configuration                                        |
| `rambo version`  | Print the version                                              |

Every command except `serve` runs as the owner of the data, never as
root, and writes an audit line to the system log. A refusal is printed
after `rambo:` on standard error, with exit code 1.

## Testing

- `make check-all` runs every check
- A check that could not run ends with exit code 9
- Details: [docs/building.md](docs/building.md)

## Documents

| Path        | Content                                                    |
|-------------|------------------------------------------------------------|
| `deploy/`   | rc.d script, update script and a Hiawatha example (OpenBSD) |
| `CHANGELOG` | the releases, newest first                                 |
| `LICENSE`   | Apache License 2.0 with LLVM Exceptions                    |

## License

Copyright (c) 2026 Heiko Zimmermann <code@heiko-zimmermann.com>

RAMBO is licensed under the Apache License 2.0 with LLVM Exceptions; see LICENSE.
Issues, questions and patches go to code@heiko-zimmermann.com.

## Checking a release

A release is an archive `rambo-X.Y.Z.tar.gz` of the tree at the tag
vX.Y.Z, its signify signature and a SHA256 file, on the release page.
The public key is `rambo-0.pub` in the root of the repository:

```sh
signify -V -p rambo-0.pub -x rambo-X.Y.Z.tar.gz.sig -m rambo-X.Y.Z.tar.gz
```
