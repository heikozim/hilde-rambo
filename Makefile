# The gates of rambo.  `make check-all` runs every gate in GATES; the list
# is here and only here.  A gate that could not run ends with exit 9.
# Tests and builds run on the build host RAMBO_HOST in a container image
# with Hilde and Wolly (scripts/run.sh; the host from the environment or
# scripts/remote.env).

GATES = check-text check-size check-comments check-image
# local.mk, where a checkout has one, adds checks of its own.
-include local.mk
HILDE_TREE ?= ../hilde
WOLLY_TREE ?= ../wolly
RAMBO_SOURCES := $(shell find src cmd -name '*.hi[qh]' 2> /dev/null | sort)
WOLLY_SOURCES := $(foreach m,$(shell grep -v '^\#' scripts/wolly-modules.txt),$(wildcard $(WOLLY_TREE)/src/Wolly/$(m).hi[qh] $(WOLLY_TREE)/src/Wolly/$(m).test.hiq))

.PHONY: check-all check-docs $(GATES)

check-all: $(GATES)
	@echo "All checks passed ($(words $(GATES)) gates)"

check-docs: check-text

check-text:
	perl scripts/check-text.pl

check-size:
	perl scripts/check-size.pl

check-comments:
	@test -r $(HILDE_TREE)/scripts/check-comments.py || { echo "ABORT: $(HILDE_TREE)/scripts/check-comments.py missing"; exit 9; }
	python3 $(HILDE_TREE)/scripts/check-comments.py $(RAMBO_SOURCES) $(WOLLY_SOURCES)

check-image:
	bash scripts/run.sh gate.sh
