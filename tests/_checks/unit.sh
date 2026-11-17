#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: run the Lua unit tests of the extension modules, and print each
# case as one TAP line.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

status=0
report="$(quarto pandoc lua "${tests_dir}/unit/run.lua" 2>&1)" || status=$?

while IFS= read -r line; do
	case "${line}" in
	'pass  '*) tap_ok "${line#pass  }" ;;
	'FAIL  '*) tap_not_ok "${line#FAIL  }" "the unit test to pass" ;;
	'      '*) printf '# %s\n' "${line#      }" ;;
	esac
done <<<"${report}"

if [ "${status}" -ne 0 ]; then
	tap_not_ok "unit-run-exit" "run.lua to exit 0, it exited ${status}"
fi
if [ "${tap_n}" -eq 0 ]; then
	printf 'Bail out! the unit tests printed no result:\n%s\n' "${report}"
	exit 1
fi
tap_done
