#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: alternative texts of a Typst PDF.
#
# Usage: accessibility.sh math-alt
#        accessibility.sh elements
#        accessibility.sh logo-alt
#        accessibility.sh logo-preset
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format accessibility.sh

# Succeed when the PDF keeps the alternative text of both equations.
math_alt_kept() {
	local alts
	alts="$(pdf_alt_texts "${output}")"
	grep -qxF 'Mass equals energy over the speed of light squared.' <<<"${alts}" &&
		grep -qxF 'The sum of one over n squared tends to pi squared over six.' <<<"${alts}"
}

# Succeed when the PDF gives the state of each task and the TeX source of each
# equation as alternative texts.
elements_alt_kept() {
	local alts
	alts="$(pdf_alt_texts "${output}")"
	grep -qxF 'Done' <<<"${alts}" &&
		grep -qxF 'Not done' <<<"${alts}" &&
		grep -qxF 'E = mc^2' <<<"${alts}" &&
		grep -qxF '\\sum_{n=1}^3 n = 6' <<<"${alts}"
}

# Succeed when the Typst source holds the logo with an alternative text.
# $1 alternative text.
logo_delivered() {
	grep -qF "mc-logo" "${typ}" && grep -qF "alt: \"$1\"" "${typ}"
}

case "${1:-}" in
math-alt)
	find_verapdf
	expect "math-alt-kept" "both equation alternative texts in the PDF" math_alt_kept
	expect "math-alt-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
elements)
	find_verapdf
	expect "elements-alt-kept" "the task states and the TeX source of the maths as alternative texts in the PDF" elements_alt_kept
	expect "elements-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
logo-alt)
	expect "logo-user-alt" "the user brand logo in Typst with the alt text 'A grey rectangle.'" logo_delivered 'A grey rectangle.'
	;;
logo-preset)
	expect "logo-preset-alt" "the preset logo in Typst with its alt text" logo_delivered 'Mickaël Canouil logo'
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
