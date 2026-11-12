#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the layout of each document type, read from the text of the PDF.
#
# Usage: types.sh compact <preset>
#        types.sh compact-short <preset>
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

# Answer the extent of the shapes of the motif of a preset, as "left bottom" in view box units (0 to 100).
# $1 preset.
motif_extent() {
	local name
	name="$(awk '/^motif:/ { print $2 }' "${ext_dir}/presets/$1.yml")"
	typst_value "${typ}" mc-motif-extent "mc-motif-extent(\"${name}\").values().map(str).join(\" \")" | tr -d '"'
}

# Succeed when no word that starts above the bottom of the shapes of the corner motif reaches into them.
# The motif is 80 mm wide, as in typst/types/report.typ.
# $1 preset.
clear_of_motif() {
	local width extent
	width="$(pdftotext -bbox -f 1 -l 1 "${output}" - | sed -nE 's/.*<page width="([0-9.]+)".*/\1/p')"
	extent="$(motif_extent "$1")"
	[ -n "${width}" ] && [ -n "${extent}" ] &&
		page1_words | awk -v width="${width}" -v extent="${extent}" '
			BEGIN {
				split(extent, e, " ")
				size = 80 / 25.4 * 72
				left = width - (100 - e[1]) / 100 * size
				bottom = e[2] / 100 * size
			}
			$2 < bottom && $3 > left { bad = 1 }
			END { exit bad }'
}

# Succeed when page 1 holds the title, the footer and at least three lines of paragraph.
first_paragraph_long() {
	[ "$(pdf_page_text "${output}" 1 | grep -c .)" -ge 5 ]
}

case "${1:-}" in
compact)
	expect "compact-first-page" "the title, the abstract and the first heading on page 1" compact_first_page
	expect "compact-headings-inline" "two level 1 headings on page 1" compact_headings_inline
	expect "compact-no-gap" "the abstract less than 15 mm below the author line" compact_no_gap
	expect "compact-clear-of-motif" "no text inside the shapes of the ${2:?compact needs a preset} motif" clear_of_motif "$2"
	;;
compact-short)
	expect "compact-clear-of-motif" "no text inside the shapes of the ${2:?compact-short needs a preset} motif" clear_of_motif "$2"
	expect "compact-short-paragraph" "a first paragraph of several lines, so a line can reach the motif" first_paragraph_long
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
