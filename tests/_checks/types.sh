#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the layout of each document type, read from the text of the PDF.
#
# Usage: types.sh compact
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format types.sh
need pdftotext

# Succeed when page 1 holds the title, the abstract and the first level 1 heading, so there is no cover.
compact_first_page() {
	local text
	text="$(pdf_page_text "${output}" 1)"
	grep -qF 'Compact report' <<<"${text}" &&
		grep -qF 'Abstract' <<<"${text}" &&
		grep -qF 'This abstract opens page 1.' <<<"${text}" &&
		grep -qE 'Introduction' <<<"${text}"
}

# Succeed when the second level 1 heading follows the first on the same page, not on a page of its own.
compact_headings_inline() {
	local text
	text="$(pdf_page_text "${output}" 1)"
	grep -qE 'Introduction' <<<"${text}" && grep -qE 'Study design' <<<"${text}"
}

case "${1:-}" in
compact)
	expect "compact-first-page" "the title, the abstract and the first heading on page 1" compact_first_page
	expect "compact-headings-inline" "two level 1 headings on page 1" compact_headings_inline
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
