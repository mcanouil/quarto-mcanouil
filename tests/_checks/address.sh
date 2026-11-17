#!/usr/bin/env bash
# shellcheck disable=SC2154 # output is set by lib.sh
set -euo pipefail

# Shared helpers of the check hooks of the address window types (letter and invoice): word boxes,
# pixels, fold marks and page text. Source lib.sh first.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

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
