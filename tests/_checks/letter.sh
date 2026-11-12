#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the letter document type, read from the word boxes, the pixels and the PDF text.
#
# Usage: letter.sh nf | din | en | override | fields
#
# Window geometry, in millimetres from the top left of an A4 page:
#   NF Z 11-001: window at x 110, y 50, 80 wide and 35 high; fold marks at 99 and 198.
#   DIN 5008 form B: window at x 20, y 45, 85 wide and 45 high; reference block at x 125, y 50,
#   75 wide; fold marks at 105 and 210; punch mark at 148.5.
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format letter.sh
need pdftotext
need pdftoppm

# Resolution of the pixel checks.
dpi=100

# Answer the words of page 1 as "xMin yMin xMax yMax word" in millimetres.
page1_words_mm() {
	pdftotext -bbox -f 1 -l 1 "${output}" - |
		sed -nE 's/.*<word xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*)<\/word>.*/\1 \2 \3 \4 \5/p' |
		awk '{ printf "%.2f %.2f %.2f %.2f %s\n", $1 * 25.4 / 72, $2 * 25.4 / 72, $3 * 25.4 / 72, $4 * 25.4 / 72, $5 }'
}

# Succeed when the first word of the recipient sits in the window: its left edge within 2 mm of the window
# left edge, its box top at most 2 mm above the window top (the box includes the ascent of the line), and the last line of the address ends inside the window.
# $1 first word. $2 last line word. $3 window x. $4 window y. $5 window width. $6 window height.
recipient_in_window() {
	page1_words_mm | awk -v first="$1" -v last="$2" -v x="$3" -v y="$4" -v w="$5" -v h="$6" '
		$5 == first && !f { f = 1; ok = ($1 >= x && $1 <= x + 2 && $2 >= y - 2 && $2 <= y + h) }
		$5 == last && !l { l = 1; fits = ($3 <= x + w && $4 <= y + h) }
		END { exit !(f && l && ok && fits) }'
}

# Succeed when the left edge of a word is within a tolerance of a value.
# $1 word. $2 minimum x. $3 maximum x.
word_x_between() {
	page1_words_mm | awk -v word="$1" -v lo="$2" -v hi="$3" '$5 == word && !f { f = 1; ok = ($1 >= lo && $1 <= hi) } END { exit !(f && ok) }'
}

# Succeed when a word starts at or below a vertical position.
# $1 word. $2 minimum y.
word_below() {
	page1_words_mm | awk -v word="$1" -v lo="$2" '$5 == word && !f { f = 1; ok = ($2 >= lo) } END { exit !(f && ok) }'
}

# Render page 1 at the resolution of the check, again when the PDF is newer, and answer the PPM path.
page1_pixels() {
	local image="${output%.pdf}-letter"
	if [ ! -f "${image}.ppm" ] || [ "${output}" -nt "${image}.ppm" ]; then
		pdftoppm -r "${dpi}" -f 1 -l 1 -singlefile "${output}" "${image}"
	fi
	printf '%s.ppm' "${image}"
}

# Succeed when a mark is inked at a vertical position within 1.5 mm of the left edge of the page: some pixel
# of the column band differs from the paper.
# $1 y in millimetres. $2 x in millimetres, inside the mark.
mark_at() {
	local image y_px x_px dy paper pixel_value
	image="$(page1_pixels)"
	x_px="$(awk -v x="$2" -v d="${dpi}" 'BEGIN { printf "%d", x * d / 25.4 }')"
	paper="$(pixel "${image}" 40 3)"
	for dy in -1 0 1; do
		y_px="$(awk -v y="$1" -v d="${dpi}" -v dy="${dy}" 'BEGIN { printf "%d", y * d / 25.4 + dy }')"
		pixel_value="$(pixel "${image}" "${x_px}" "${y_px}")"
		[ "$(colour_distance "${pixel_value}" "${paper}")" -gt 60 ] && return 0
	done
	return 1
}

# Succeed when a mark is inked at every given vertical position, 2 mm from the left edge.
# $@ y in millimetres.
marks_at() {
	local y
	for y in "$@"; do
		mark_at "${y}" 2 || return 1
	done
}

# Succeed when no mark is inked at a vertical position, 2 mm from the left edge.
# $1 y in millimetres.
no_mark_at() {
	! mark_at "$1" 2
}

# Succeed when the page text lacks a fixed string.
# $1 string.
page_lacks() {
	! pdf_page_text "${output}" 1 | grep -qF -- "$1"
}

# Succeed when the PDF holds a figure with an alternative text.
# $1 text.
has_alt() {
	pdf_alt_texts "${output}" | grep -qxF -- "$1"
}

# Succeed when the first page text holds every given string, in order.
# $@ strings.
in_order() {
	local text rest needle
	text="$(pdf_text "${output}" | tr -s '[:space:]' ' ')"
	rest="${text}"
	for needle in "$@"; do
		case "${rest}" in
		*"${needle}"*) rest="${rest#*"${needle}"}" ;;
		*) return 1 ;;
		esac
	done
}

# Succeed when the page text holds a fixed string.
# $1 string.
page_has() {
	pdf_page_text "${output}" 1 | grep -qF -- "$1"
}

nf_checks() {
	expect "letter-nf-window" "the recipient in the window at x 110, y 50, 80 by 35 mm" recipient_in_window Company Paris 110 50 80 35
	expect "letter-nf-fold-marks" "fold marks at 99 and 198 mm" marks_at 99 198
	expect "letter-nf-no-punch-mark" "no punch mark at 148.5 mm" no_mark_at 148.5
	expect "letter-nf-sender-left" "the sender at the left margin, above the window" word_x_between Mickaël 19 22
	expect "letter-nf-subject-below" "the subject below the window" word_below Proposition 85
}

case "${1:-}" in
nf)
	nf_checks
	expect "letter-nf-date" "the French place and date" page_has "Lille, le 11 novembre 2026"
	expect "letter-nf-subject-label" "the French subject label" page_has "Objet : Proposition de formation"
	;;
din)
	expect "letter-din-window" "the recipient in the window at x 20, y 45, 85 by 45 mm" recipient_in_window Beispiel München 20 45 85 45
	expect "letter-din-fold-marks" "fold marks at 105 and 210 mm, punch mark at 148.5 mm" marks_at 105 210 148.5
	expect "letter-din-reference-block" "the reference block at x 125 with the German labels" word_x_between Unser 124 127
	expect "letter-din-reference-block-text" "the references and the date in the block" in_order "Ihr Zeichen" "A-77" "Unser Zeichen" "2026-014" "Datum" "Berlin, 11. November 2026"
	expect "letter-din-no-english" "no English reference label" page_lacks Reference
	;;
en)
	expect "letter-en-nf-window" "the NF window for another language" recipient_in_window Company London 110 50 80 35
	expect "letter-en-date" "the English place and date" page_has "Lille, 11 November 2026"
	expect "letter-en-subject-label" "the English subject label" page_has "Subject: Training proposal"
	;;
override)
	expect "letter-override-din-window" "a French letter in the DIN window" recipient_in_window Company Paris 20 45 85 45
	expect "letter-override-french-date" "the French place and date in the DIN reference block" page_has "Lille, le 11 novembre 2026"
	;;
fields)
	find_verapdf
	expect "letter-fields-order" "subject, opening, body, closing, cc, enclosures and postscript in order" in_order "Subject: Training proposal" "Dear Sir or Madam," "First paragraph" "Second paragraph" "Yours faithfully," "Mickaël Canouil" "Cc" "Alex Copy" "Enclosures" "Programme" "P.S." "Remember the date."
	expect "letter-fields-signature-image" "the signature image, with its alternative text" has_alt Signature
	expect "letter-fields-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
