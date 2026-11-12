#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, typ, ext_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the kept Typst file compiles without a warning, such as "document did not converge".
#
# Usage: convergence.sh <name>
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format convergence.sh

# Succeed when Typst compiles the kept file, and prints no warning and no error.
compiles_quietly() {
	local result scratch
	scratch="$(mktemp -d)"
	result="$(quarto typst compile --root / --font-path "${ext_dir}/fonts" --pdf-standard ua-1 "${typ}" "${scratch}/out.pdf" 2>&1)" || {
		printf '%s\n' "${result}" >&2
		rm -rf "${scratch}"
		return 1
	}
	rm -rf "${scratch}"
	if grep -qE '^(warning|error)' <<<"${result}"; then
		printf '%s\n' "${result}" >&2
		return 1
	fi
}

expect "compile-quiet-${1:?convergence needs a name}" "no Typst warning when the kept file compiles" compiles_quietly
tap_done
