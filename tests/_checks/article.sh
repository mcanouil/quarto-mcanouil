#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the article document type, read from the PDF text, the word boxes and the pixels.
#
# Usage: article.sh <preset>
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format article.sh
need pdftotext
need pdftoppm

# Answer the words of a page as "xMin yMin xMax yMax word" in points.
# $1 page number.
page_words() {
	pdftotext -bbox -f "$1" -l "$1" "${output}" - |
		sed -nE 's/.*<word xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*)<\/word>.*/\1 \2 \3 \4 \5/p'
}

# Answer the page width in points.
page_width() {
	pdftotext -bbox -f 1 -l 1 "${output}" - | sed -nE 's/.*<page width="([0-9.]+)".*/\1/p'
}

# Answer the left edge of the outer margin column in points: the page width less the far distance, the
# width and the separation of the outer margin that the kept Typst file sets.
outer_margin_left() {
	local width
	width="$(page_width)"
	awk -v width="${width}" '
		/outer: \(/ { inside = 1 }
		inside && /far:/ { gsub(/[^0-9.]/, "", $2); far = $2 }
		inside && /width:/ { gsub(/[^0-9.]/, "", $2); wide = $2 }
		inside && /sep:/ { gsub(/[^0-9.]/, "", $2); sep = $2; inside = 0 }
		END { printf "%.2f", width - (far + wide + sep) / 25.4 * 72 }' "${typ}"
}

# Answer the page number that holds a word, or nothing.
# $1 word.
page_of_word() {
	local page total
	total="$(pdf_page_count "${output}")"
	for ((page = 1; page <= total; page++)); do
		if page_words "${page}" | awk -v word="$1" '$5 == word { found = 1 } END { exit !found }'; then
			printf '%d' "${page}"
			return 0
		fi
	done
}

# Succeed when the words of a margin note start in the outer margin, beside the paragraph that calls it, and the
# call point stays in the body column.
# $1 first word of the note. $2 call point word.
note_in_margin() {
	local page edge note_x note_y call_x call_y
	page="$(page_of_word "$1")"
	[ -n "${page}" ] || return 1
	edge="$(outer_margin_left)"
	read -r note_x note_y <<<"$(page_words "${page}" | awk -v word="$1" '$5 == word { print $1, $2; exit }')"
	read -r call_x call_y <<<"$(page_words "${page}" | awk -v word="$2" '$5 ~ word { print $3, $2; exit }')"
	[ -n "${note_x}" ] && [ -n "${call_x}" ] &&
		awk -v nx="${note_x}" -v ny="${note_y}" -v cx="${call_x}" -v cy="${call_y}" -v edge="${edge}" \
			'BEGIN { d = ny - cy; if (d < 0) d = -d; exit !(nx >= edge - 1 && cx <= edge && d < 150) }'
}

# Succeed when the credit table has its legend and the right marks for the lead and the equal roles.
credit_table() {
	local text
	text="$(pdf_page_text "${output}" "$(pdf_page_count "${output}")")"
	grep -qF 'Author contributions (CRediT)' <<<"${text}" &&
		grep -qE '^[[:space:]]*Conceptualization[[:space:]]+L[[:space:]]+E[[:space:]]*$' <<<"${text}" &&
		grep -qE '^[[:space:]]*Formal analysis[[:space:]]+L[[:space:]]+S[[:space:]]*$' <<<"${text}" &&
		grep -qE '^[[:space:]]*Supervision[[:space:]]+•' <<<"${text}" &&
		grep -qE 'L +Lead' <<<"${text}" && grep -qE 'E +Equal' <<<"${text}" && grep -qE 'S +Supporting' <<<"${text}" &&
		grep -qE 'AA[[:space:]]+BW' <<<"${text}"
}

# Succeed when the credit table is the last thing of the document, after the references.
credit_table_last() {
	local text
	text="$(pdf_text "${output}" | tr -s '[:space:]' ' ')"
	[[ "${text}" == *'J. Doe'*'Author contributions (CRediT)'* ]]
}

# Succeed when page 1 holds the title, the authors, the abstract and the keywords, and no running header.
title_block() {
	local text
	text="$(pdf_page_text "${output}" 1)"
	tr -s '[:space:]' ' ' <<<"${text}" | grep -qF 'Polygenic scores and type 2 diabetes' &&
		grep -qF 'Ana Author' <<<"${text}" && grep -qF 'Abstract' <<<"${text}" &&
		grep -qE 'Keywords:.*genetics, diabetes, risk' <<<"${text}" &&
		grep -qF 'Introduction' <<<"${text}"
}

# Succeed when the references are numbered and come before the credit table.
numbered_references() {
	pdf_text "${output}" | grep -qE '^[[:space:]]*\[1\][[:space:]]+J\. Doe' &&
		pdf_text "${output}" | tr -s '[:space:]' ' ' | grep -qE 'reference \[1\]'
}

# Succeed when the motif colour shows at the sample points of the article motif on page 1.
# $1 preset.
motif_corner_article() {
	local preset="$1" image side mode=light paper colour point
	image="$(page1_image)"
	side="$(motif_side_px mc-article-motif-size)"
	[ "${preset}" != terminal ] || mode=dark
	paper="$(hex_rgb "$(preset_value "${preset}" "${mode}" paper)")"
	colour="$(hex_rgb "$(preset_value "${preset}" "${mode}" "$(motif_token "${preset}")")")"
	[ "${side}" -gt 40 ] || return 1
	for point in $(motif_points "${preset}"); do
		shows_motif "$(motif_pixel "${image}" "${side}" "${point%,*}" "${point#*,}")" "${paper}" "${colour}" || return 1
	done
}

# Succeed when no word that starts above the bottom of the shapes of the corner motif reaches into them.
# $1 preset.
clear_of_article_motif() {
	local width extent name size_pt
	width="$(page_width)"
	name="$(awk '/^motif:/ { print $2 }' "${ext_dir}/presets/$1.yml")"
	extent="$(typst_value "${typ}" mc-motif-extent "mc-motif-extent(\"${name}\").values().map(str).join(\" \")" | tr -d '"')"
	size_pt="$(typst_value "${typ}" mc-article-motif-size 'mc-article-motif-size.pt()')"
	[ -n "${width}" ] && [ -n "${extent}" ] && [ -n "${size_pt}" ] &&
		page_words 1 | awk -v width="${width}" -v extent="${extent}" -v size="${size_pt}" '
			BEGIN {
				split(extent, e, " ")
				left = width - (100 - e[1]) / 100 * size
				bottom = e[2] / 100 * size
			}
			$2 < bottom && $3 > left { bad = 1 }
			END { exit bad }'
}

case "${1:-}" in
gold | mono | quarto | terminal)
	find_verapdf
	expect "article-title-block" "the title, the authors, the abstract, the keywords and the first heading on page 1" title_block
	expect "article-margin-notes" "the margin div text in the outer margin, beside its paragraph" note_in_margin Sidenote Callpoint
	expect "article-footnote-margin" "the footnote text in the outer margin" note_in_margin Footnoted Callpoint
	expect "article-numbered-references" "a numbered reference list and a numbered citation" numbered_references
	expect "credit-table" "the CRediT table with L, E, S marks, header initials and its legend" credit_table
	expect "credit-table-last" "the CRediT table after the references" credit_table_last
	expect "article-first-page-motif" "the ${1} motif colour at the motif points of page 1" motif_corner_article "$1"
	expect "article-clear-of-motif" "no word inside the shapes of the ${1} motif" clear_of_article_motif "$1"
	expect "article-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
