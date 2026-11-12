#!/usr/bin/env bash
set -euo pipefail

# Check hook: run the Lua unit tests of the extension modules, and print each
# case as one TAP line.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

report="$(quarto pandoc lua "${tests_dir}/unit/run.lua" 2>&1 || true)"

while IFS= read -r line; do
	case "${line}" in
	'pass  '*) tap_ok "${line#pass  }" ;;
	'FAIL  '*) tap_not_ok "${line#FAIL  }" "the unit test to pass" ;;
	'      '*) printf '# %s\n' "${line#      }" ;;
	esac
done <<<"${report}"

if [ "${tap_n}" -eq 0 ]; then
	printf 'Bail out! the unit tests printed no result:\n%s\n' "${report}"
	exit 1
fi
tap_done
