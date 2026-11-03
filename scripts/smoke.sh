#!/usr/bin/env bash
# Start the full config headless, dump :messages, fail on errors.
# Lines with E<digits>: or "Error" fail the run; "WARN" lines are printed only.
set -u
msgs="$(mktemp)"
errs="$(mktemp)"
trap 'rm -f "$msgs" "$errs"' EXIT
rm -f "$msgs"
SMOKE_OUT="$msgs" nvim --headless \
  +'sleep 3' \
  +'lua vim.fn.writefile(vim.split(vim.api.nvim_exec2("messages", { output = true }).output, "\n"), vim.env.SMOKE_OUT)' \
  +qa 2>"$errs"
status=$?
cat "$msgs" "$errs" 2>/dev/null
if [ "$status" -ne 0 ]; then
  echo "smoke: FAILED (nvim exited $status)" >&2
  exit 1
fi
if [ ! -f "$msgs" ]; then
  echo "smoke: FAILED (messages file not written)" >&2
  exit 1
fi
if grep -Eq 'E[0-9]+:|Error' "$msgs" "$errs"; then
  echo "smoke: FAILED" >&2
  exit 1
fi
echo "smoke: ok"
