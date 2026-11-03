.PHONY: test smoke

test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/cc {minimal_init='tests/minimal_init.lua', sequential=true}"

smoke:
	scripts/smoke.sh
