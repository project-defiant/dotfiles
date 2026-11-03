#!/usr/bin/env bash
# Start the full config headless, dump :messages, fail on errors.
# Lines with E<digits>: or "Error" fail the run; "WARN" lines are printed only.
set -u
msgs="$(mktemp)"
errs="$(mktemp)"
trap 'rm -f "$msgs" "$errs"' EXIT
nvim --headless \
  +'sleep 3' \
  +"redir! > $msgs | silent messages | redir END" \
  +qa 2>"$errs"
cat "$msgs" "$errs"
if grep -Eq 'E[0-9]+:|Error' "$msgs" "$errs"; then
  echo "smoke: FAILED" >&2
  exit 1
fi
echo "smoke: ok"
