.PHONY: serve serve-internal build build-internal

serve:
	zensical serve -a 0.0.0.0:8000

serve-internal:
	zensical serve -f zensical-internal.toml -a 0.0.0.0:8001

build:
	zensical build

build-internal:
	zensical build -f zensical-internal.toml

-include Makefile.ctx
