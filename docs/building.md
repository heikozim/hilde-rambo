# Building and testing RAMBO

The checks are in the `Makefile`: `make check-all` runs every one, and a
check that could not run ends with exit 9.

The builds and tests run in a container image with the Hilde compiler and
its standard library on a build host that `scripts/remote.sh` reaches by
ssh. `scripts/remote.env.example` names the settings:

| Setting            | Meaning                          |
|--------------------|----------------------------------|
| `RAMBO_HOST`       | the build host                   |
| `RAMBO_SSH_USER`   | the user on the build host       |
| `RAMBO_SSH_PORT`   | the ssh port of the build host   |
| `RAMBO_REMOTE_DIR` | the work directory there         |

`scripts/run.sh` sends this tree and the Wolly tree it builds on
(`WOLLY_TREE`) to the container and runs one script of `scripts/image/`
there. `scripts/wolly-modules.txt` lists the modules of Wolly the checks
take with RAMBO's own.
