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

# Succeed when two level 1 headings both sit on page 1.
compact_headings_inline() {
	local text
	text="$(pdf_page_text "${output}" 1)"
	grep -qE 'Introduction' <<<"${text}" && grep -qE 'Study design' <<<"${text}"
}

# Answer the words of page 1 as "xMin yMin xMax yMax word" in points.
page1_words() {
	pdftotext -bbox -f 1 -l 1 "${output}" - |
		sed -nE 's/.*<word xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*)<\/word>.*/\1 \2 \3 \4 \5/p'
}

# Succeed when the abstract label starts less than 15 mm below the author line.
compact_no_gap() {
	local author_bottom abstract_top
	author_bottom="$(page1_words | awk '$5 == "Author" { print $4; exit }')"
	abstract_top="$(page1_words | awk '$5 == "Abstract" { print $2; exit }')"
	[ -n "${author_bottom}" ] && [ -n "${abstract_top}" ] &&
		awk -v top="${abstract_top}" -v bottom="${author_bottom}" 'BEGIN { exit !((top - bottom) / 72 * 25.4 < 15) }'
}

# Succeed when no word that starts above the bottom of the 80 mm corner motif reaches into the motif square.
compact_clear_of_motif() {
	local width
	width="$(pdftotext -bbox -f 1 -l 1 "${output}" - | sed -nE 's/.*<page width="([0-9.]+)".*/\1/p')"
	[ -n "${width}" ] &&
		page1_words | awk -v left="$(awk -v w="${width}" 'BEGIN { print w - 80 / 25.4 * 72 }')" -v bottom="$(awk 'BEGIN { print 80 / 25.4 * 72 }')" '
			$2 < bottom && $3 > left { bad = 1 }
			END { exit bad }'
}

case "${1:-}" in
compact)
	expect "compact-first-page" "the title, the abstract and the first heading on page 1" compact_first_page
	expect "compact-headings-inline" "two level 1 headings on page 1" compact_headings_inline
	expect "compact-no-gap" "the abstract less than 15 mm below the author line" compact_no_gap
	expect "compact-clear-of-motif" "no text inside the 80 mm corner motif square" compact_clear_of_motif
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
