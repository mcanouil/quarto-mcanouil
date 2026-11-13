#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the memo document type, read from the PDF text, the word boxes, the pixels and the tag tree.
#
# Usage: memo.sh kind <note|minutes|agenda|brief> <preset>
#        memo.sh band <preset>
#        memo.sh missing <preset>
#        memo.sh long-title <preset>
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format memo.sh
need pdftotext
need pdfinfo
need pdftoppm

# Answer the words of a page as "xMin yMin xMax yMax word" in points.
# $1 page number.
page_words() {
	pdftotext -bbox -f "$1" -l "$1" "${output}" - |
		sed -nE 's/.*<word xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*)<\/word>.*/\1 \2 \3 \4 \5/p'
}

# Answer the width and height of page 1 in points.
page_size() {
	pdftotext -bbox -f 1 -l 1 "${output}" - | sed -nE 's/.*<page width="([0-9.]+)" height="([0-9.]+)".*/\1 \2/p'
}

# Answer the structure tree of the PDF, one element a line.
struct_tree() {
	pdfinfo -struct "${output}"
}

# Answer the text of page 1 with all whitespace removed: letter-spaced labels come out of pdftotext with
# gaps inside the words.
page1_flat() {
	pdf_page_text "${output}" 1 | tr -d '[:space:]'
}

# Succeed when the text of page 1 holds every string, in any case and whatever the spacing.
# $@ strings.
page1_has() {
	local text string
	text="$(page1_flat)"
	for string in "$@"; do
		grep -qiF -- "${string//[[:space:]]/}" <<<"${text}" || {
			printf '# page 1 lacks "%s"\n' "${string}"
			return 1
		}
	done
}

# Succeed when the kind label and the fields of a memo kind are in the text of page 1.
# $1 kind.
kind_fields() {
	case "$1" in
	note) page1_has Note To 'Data team' From 'M. Canouil' Date '11 Nov 2026' ;;
	minutes) page1_has Minutes 'Date and time' '11 Nov 2026, 14:00' Present 'MC, AA, BW' Absent CD Decisions Action Owner Due 'Book room' ;;
	agenda) page1_has Agenda 'Date and time' '18 Nov 2026, 10:00' Place 'Room 4' Participants 'MC, AA, BW, CD' 'Welcome and apologies' ;;
	brief) page1_has Brief Date '11 November 2026' Audience 'Product leads' Purpose 'Agree the go or no go' ;;
	esac
}

# Succeed when the structure tree holds a table before the first heading of the body, so the banner
# metadata is a real table with header cells.
banner_table() {
	local tree table heading
	tree="$(struct_tree)"
	table="$(grep -n -m1 -E '^[[:space:]]*Table' <<<"${tree}" | cut -d: -f1)"
	heading="$(grep -n -m1 -E '^[[:space:]]*H[1-6]' <<<"${tree}" | cut -d: -f1)"
	[ -n "${table}" ] && { [ -z "${heading}" ] || [ "${table}" -lt "${heading}" ]; } &&
		grep -qE '^[[:space:]]*(TH|TD)' <<<"${tree}"
}

# Answer the number of header cells of the banner table: the header cells before the first heading.
banner_columns() {
	struct_tree | awk '
		/^[[:space:]]*H[1-6]/ { exit }
		/^[[:space:]]*TH[[:space:]]*</ { cells++ }
		END { print cells + 0 }'
}

# Succeed when the text of page 1 lacks a label.
# $1 label.
page1_lacks() {
	! grep -qF -- "$1" <<<"$(page1_flat)"
}

# Answer the pixel of page n at a point, in pixels at 50 dpi, as "r g b".
# $1 page number. $2 x. $3 y, negative from the bottom.
page_pixel() {
	local image="${output%.pdf}-band-$1" width height x="$2" y="$3"
	if [ ! -f "${image}.ppm" ] || [ "${output}" -nt "${image}.ppm" ]; then
		pdftoppm -r 50 -f "$1" -l "$1" -singlefile "${output}" "${image}"
	fi
	read -r width height <<<"$(ppm_size "${image}.ppm")"
	[ "${y}" -ge 0 ] || y=$((height + y))
	[ "${x}" -ge 0 ] || x=$((width + x))
	pixel "${image}.ppm" "${x}" "${y}"
}

# Succeed when every page has the band at its bottom, in the ground colours, and the page number.
band_every_page() {
	local preset="$1" mode=light page total left right
	[ "${preset}" != terminal ] || mode=dark
	total="$(pdf_page_count "${output}")"
	[ "${total}" -ge 2 ] || return 1
	left="$(hex_rgb "$(preset_value "${preset}" "${mode}" ground-1)")"
	right="$(hex_rgb "$(preset_value "${preset}" "${mode}" ground-2)")"
	for ((page = 1; page <= total; page++)); do
		[ "$(colour_distance "$(page_pixel "${page}" 2 -3)" "${left}")" -lt 40 ] || return 1
		[ "$(colour_distance "$(page_pixel "${page}" -3 -3)" "${right}")" -lt 40 ] || return 1
		pdf_page_text "${output}" "${page}" | grep -qE "${page} ?/ ?${total}" || return 1
	done
}

# Succeed when the banner table has the two columns of the fields that are set, and the label of the
# field that is not set is absent.
missing_fields() {
	[ "$(banner_columns)" = 2 ] && page1_lacks From
}

# Succeed when the memo has one to three pages.
page_range() {
	local total
	total="$(pdf_page_count "${output}")"
	[ "${total}" -ge 1 ] && [ "${total}" -le 3 ]
}

# Succeed when the banner shows the ground colour at the top left of page 1 and no text of the body page
# starts above the banner.
banner_ground() {
	local preset="$1" mode=light
	[ "${preset}" != terminal ] || mode=dark
	[ "$(colour_distance "$(page_pixel 1 2 2)" "$(hex_rgb "$(preset_value "${preset}" "${mode}" ground-1)")")" -lt 40 ]
}

# Succeed when no word of page 1 reaches into the shapes of the banner motif, or straddles the top edge
# of the band, and the last word of the title sits on the ground of the banner, above the first heading.
# $1 preset.
long_title_clear() {
	local size width height extent band last_y
	size="$(typst_value "${typ}" mc-memo-motif-size 'mc-memo-motif-size.pt()')"
	band="$(typst_value "${typ}" mc-memo-band-height 'mc-memo-band-height.pt()')"
	read -r width height <<<"$(page_size)"
	extent="$(typst_value "${typ}" mc-motif-extent "mc-motif-extent(\"$(awk '/^motif:/ { print $2 }' "${ext_dir}/presets/$1.yml")\").values().map(str).join(\" \")" | tr -d '"')"
	[ -n "${size}" ] && [ -n "${band}" ] && [ -n "${width}" ] && [ -n "${extent}" ] || return 1
	page_words 1 | grep -q ' stop$' || return 1
	page_words 1 | awk -v width="${width}" -v height="${height}" -v size="${size}" -v band="${band}" -v extent="${extent}" '
		BEGIN {
			split(extent, e, " ")
			left = width - (100 - e[1]) / 100 * size
			bottom = e[2] / 100 * size
			top_band = height - band
		}
		$2 < bottom && $3 > left { bad = 1 }
		$2 < top_band && $4 > top_band { bad = 1 }
		END { exit bad }' || return 1
	last_y="$(page_words 1 | awk '$5 == "stop" { print $4; exit }')"
	[ "$(page_words 1 | awk -v y="${last_y}" '$5 == "Context" { print ($2 > y) ? 1 : 0; exit }')" = 1 ]
}

case "${1:-}" in
kind)
	find_verapdf
	expect "memo-kind-${2:?kind needs a memo kind}" "the ${2} label and its banner fields on page 1" kind_fields "$2"
	expect "memo-fields-table" "the banner metadata as a table with header cells before the first heading" banner_table
	expect "memo-pages" "one to three pages" page_range
	expect "memo-banner-ground-${3:?kind needs a preset}" "the ground colour at the top left of page 1" banner_ground "$3"
	expect "memo-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
band)
	expect "memo-band-every-page" "the ground band and the page number at the bottom of every page" band_every_page "${2:?band needs a preset}"
	;;
missing)
	expect "memo-missing-fields" "one banner column for each field that is set, and no label for the others" missing_fields
	;;
long-title)
	expect "long-title-no-overlap" "no banner word inside the shapes of the ${2:?long-title needs a preset} motif or across the band, and the title inside the banner" \
		long_title_clear "$2"
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
