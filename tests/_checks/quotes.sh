#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the block quotes of a Typst PDF, read from its text, its pixels and its tag tree.
#
# Usage: quotes.sh <preset>
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format quotes.sh
need pdftotext
need pdftoppm
need pdfinfo

readonly QUOTE_TEXT='Design for the reader who cannot see the colours'
readonly ATTRIBUTION='Mickaël Canouil, 2026'

# Answer the PDF text on one line per paragraph run, spaces squeezed.
flat_text() {
	pdf_text "${output}" | tr -s '[:space:]' ' '
}

# Answer the first word box of a word on page 1 as "xMin yMin xMax yMax", in points.
# $1 word.
word_box() {
	pdftotext -bbox -f 1 -l 1 "${output}" - |
		sed -nE 's/.*<word xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*)<\/word>.*/\1 \2 \3 \4 \5/p' |
		awk -v word="$1" '$5 == word { print $1, $2, $3, $4; exit }'
}

# Answer the pixel of page 1 at 100 dpi, at a position in points.
# $1 x. $2 y.
page_pixel() {
	local image="${output%.pdf}-quote"
	if [ ! -f "${image}.ppm" ] || [ "${output}" -nt "${image}.ppm" ]; then
		pdftoppm -r 100 -f 1 -l 1 -singlefile "${output}" "${image}"
	fi
	local px py
	px="$(awk -v v="$1" 'BEGIN { printf "%d", v * 100 / 72 }')"
	py="$(awk -v v="$2" 'BEGIN { printf "%d", v * 100 / 72 }')"
	pixel "${image}.ppm" "${px}" "${py}"
}

# Succeed when a pixel differs from a colour by more than a small amount.
# $1 pixel, "r g b". $2 colour, "r g b".
differs() {
	[ "$(colour_distance "$1" "$2")" -gt 30 ]
}

# Succeed when a pixel is close to a colour.
# $1 pixel, "r g b". $2 colour, "r g b".
near() {
	[ "$(colour_distance "$1" "$2")" -le 30 ]
}

# Succeed when the quote text and the attribution are in the PDF text, and the text of the second quote too.
text_present() {
	local text
	text="$(flat_text)"
	[[ "${text}" == *"${QUOTE_TEXT}"* ]] && [[ "${text}" == *'A quote without attribution stays a plain quote'* ]]
}

# Succeed when the attribution is in the text, the dash that marked it is not, and only one quote has one.
attribution_clean() {
	local text
	text="$(flat_text)"
	[[ "${text}" == *"${ATTRIBUTION}"* ]] &&
		[[ "${text}" != *"- ${ATTRIBUTION}"* ]] && [[ "${text}" != *"— ${ATTRIBUTION}"* ]] &&
		[[ "${text}" != *"– ${ATTRIBUTION}"* ]] && [[ "${text}" != *"-- ${ATTRIBUTION}"* ]] &&
		[ "$(count "${typ}" 'attribution: [')" -eq 1 ]
}

# Succeed when a pixel on a line of the page differs from the paper.
# $1 paper, "r g b". $2 axis that moves, x or y. $3 fixed coordinate. $4 first and $5 last value, in points.
any_differs() {
	local value
	for value in $(seq "$(printf '%.0f' "$4")" "$(printf '%.0f' "$5")"); do
		if [ "$2" = x ]; then
			differs "$(page_pixel "${value}" "$3")" "$1" && return 0
		else
			differs "$(page_pixel "$3" "${value}")" "$1" && return 0
		fi
	done
	return 1
}

# Succeed when the preset draws its own mark beside the first quote.
# $1 preset.
decoration_drawn() {
	local preset="$1" mode=light box x0 y0 y1 paper middle inside
	[ "${preset}" != terminal ] || mode=dark
	paper="$(hex_rgb "$(preset_value "${preset}" "${mode}" paper)")"
	box="$(word_box Design)"
	[ -n "${box}" ] || return 1
	read -r x0 y0 _ y1 <<<"${box}"
	case "${preset}" in
	gold)
		middle="$(awk -v a="${y0}" -v b="${y1}" 'BEGIN { print (a + b) / 2 }')"
		any_differs "${paper}" x "${middle}" "$(awk -v x="${x0}" 'BEGIN { print x - 18 }')" "$(awk -v x="${x0}" 'BEGIN { print x - 12 }')"
		;;
	mono)
		any_differs "${paper}" y "$(awk -v x="${x0}" 'BEGIN { print x + 3 }')" "$(awk -v y="${y0}" 'BEGIN { print y - 16 }')" "$(awk -v y="${y0}" 'BEGIN { print y - 4 }')"
		;;
	quarto)
		middle="$(awk -v a="${y0}" -v b="${y1}" 'BEGIN { print (a + b) / 2 }')"
		inside="$(page_pixel "$(awk -v x="${x0}" 'BEGIN { print x - 6 }')" "${middle}")"
		near "${inside}" "$(hex_rgb "$(preset_value quarto light card)")" && differs "${inside}" "${paper}"
		;;
	terminal)
		pdf_text "${output}" | grep -qF '[QUOTE]'
		;;
	esac
}

# Succeed when the label word of the preset shows on the page, or when the preset has none.
# $1 preset.
label_shown() {
	case "$1" in
	mono) flat_text | grep -qE 'Q ?U ?O ?T ?E' ;;
	terminal) flat_text | grep -qF '[QUOTE]' ;;
	*) ! flat_text | grep -qE '\[?QUOTE\]?' ;;
	esac
}

# Succeed when the tag tree has a BlockQuote for each quote, holding the text and the attribution, and none of the decoration.
tags_clean() {
	local struct="${output%.pdf}.struct"
	pdfinfo -struct-text "${output}" >"${struct}"
	local text
	text="$(tr -s '[:space:]' ' ' <"${struct}")"
	[[ "${text}" == *"${QUOTE_TEXT}"* ]] && [[ "${text}" == *"${ATTRIBUTION}"* ]] &&
		! grep -qE 'Q ?U ?O ?T ?E|Figure|Artifact|Shape' "${struct}" &&
		[ "$(grep -cE '^  BlockQuote' "${struct}")" -eq 2 ]
}

# Answer the contrast ratio of two hex colours.
# $1 and $2 colours, "#rrggbb".
ratio() {
	awk -v a="$1" -v b="$2" '
		function hex(h,   i, n, d) { n = 0; h = tolower(h); for (i = 1; i <= length(h); i++) { d = index("0123456789abcdef", substr(h, i, 1)) - 1; n = n * 16 + d } return n }
		function lin(h,   v) { v = hex(h) / 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
		function lum(c) { return 0.2126 * lin(substr(c, 2, 2)) + 0.7152 * lin(substr(c, 4, 2)) + 0.0722 * lin(substr(c, 6, 2)) }
		BEGIN { x = lum(a); y = lum(b); if (x < y) { t = x; x = y; y = t } printf "%.2f", (x + 0.05) / (y + 0.05) }'
}

# Succeed when a foreground token reads on a background colour at 4.5:1.
# $1 preset. $2 mode. $3 foreground token. $4 background token.
readable() {
	local fg bg
	fg="$(preset_value "$1" "$2" "$3")"
	bg="$(preset_value "$1" "$2" "$4")"
	[ -n "${fg}" ] && [ -n "${bg}" ] && awk -v r="$(ratio "${fg}" "${bg}")" 'BEGIN { exit !(r >= 4.5) }'
}

# Succeed when the text and the attribution of the preset pass 4.5:1 on their backgrounds.
# $1 preset.
contrast_ok() {
	local preset="$1" mode=light
	[ "${preset}" != terminal ] || mode=dark
	case "${preset}" in
	gold) readable gold light ink paper && readable gold light accent-text paper ;;
	mono) readable mono light ink paper && readable mono light muted paper && readable mono light paper accent ;;
	quarto) readable quarto light ink card && readable quarto light accent-text tint ;;
	terminal) readable terminal "${mode}" ink paper && readable terminal "${mode}" muted paper && readable terminal "${mode}" accent-text paper ;;
	esac
}

case "${1:-}" in
gold | mono | quarto | terminal)
	find_verapdf
	expect "quote-text-${1}" "both quotes in the PDF text" text_present
	expect "quote-style-${1}" "the ${1} decoration beside the first quote, and its label where it has one" decoration_drawn "$1"
	expect "quote-label-${1}" "the label of the ${1} preset on the page, or none" label_shown "$1"
	expect "quote-attribution-${1}" "the attribution without its dash, on one quote only" attribution_clean
	expect "quote-artefact-${1}" "the quote and its attribution in the tag tree, the decoration out of it" tags_clean
	expect "quote-contrast-${1}" "4.5:1 for the quote and the attribution" contrast_ok "$1"
	expect "quote-ua1-${1}" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
