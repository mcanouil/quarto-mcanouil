#!/usr/bin/env bash
set -euo pipefail

# Check hook: the layout of a Typst PDF, read from its text, its pixels and its tag tree.
#
# Usage: pdf.sh report <preset>
#        pdf.sh report-no-author
#        pdf.sh center-alias
#        pdf.sh subdir
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format pdf.sh
need pdftotext
need pdfinfo
need pdffonts
need pdftoppm

# Motif sample points of each preset, in motif units: "x,y" pairs inside a
# shape. The first pair is the shape nearest the corner, the last one is on the
# right edge at mid motif height or the nearest shape to it.
motif_points() {
	case "$1" in
	gold) printf '99.5,0.5 99.5,50' ;;
	mono) printf '99.5,0.5 81,0.5 99.5,32 99.5,50' ;;
	quarto) printf '46,0.5 99.5,54' ;;
	terminal) printf '96,4 96,53' ;;
	esac
}

# Answer the token of the colour that a preset motif uses on its page: a light
# page uses accent, a dark page accent-high.
motif_token() {
	case "$1" in
	terminal) printf 'accent-high' ;;
	*) printf 'accent' ;;
	esac
}

# Answer the shapes of the motifs of the Typst library, one line each:
# "<motif> <kind> <numbers...> <opacity>".
typst_motif_shapes() {
	typst_value "${typ}" mc-motif-lines 'mc-motif-lines().join("\n")' | sed -E 's/^"//; s/"$//' | sed 's/\\n/\n/g'
}

# Answer the shapes of an SVG motif file, in the format of typst_motif_shapes.
# $1 motif name. $2 SVG file.
svg_motif_shapes() {
	grep -oE '<(path|rect|circle) [^>]*>' "$2" | awk -v name="$1" '
		function attr(tag, key,   m) {
			if (match(tag, " " key "=\"[^\"]*\"")) { m = substr(tag, RSTART + length(key) + 3, RLENGTH - length(key) - 4); return m }
			return ""
		}
		{
			kind = substr($1, 2)
			if (kind == "path") {
				d = attr($0, "d"); gsub(/[MLZ]/, " ", d); gsub(/ +/, " ", d); sub(/^ /, "", d); sub(/ $/, "", d)
				print name, "polygon", d, attr($0, "opacity")
			} else if (kind == "rect") {
				print name, "rect", attr($0, "x"), attr($0, "y"), attr($0, "width"), attr($0, "height"), attr($0, "opacity")
			} else {
				print name, "circle", attr($0, "cx"), attr($0, "cy"), attr($0, "r"), attr($0, "opacity")
			}
		}'
}

# Succeed when the motif colour shows at every sample point of page 1.
# $1 preset.
motif_corner() {
	local preset="$1" image side mode=light paper colour point
	image="$(page1_image)"
	side="$(motif_side_px)"
	[ "${preset}" != terminal ] || mode=dark
	paper="$(hex_rgb "$(preset_value "${preset}" "${mode}" paper)")"
	colour="$(hex_rgb "$(preset_value "${preset}" "${mode}" "$(motif_token "${preset}")")")"
	[ "${side}" -gt 50 ] || return 1
	for point in $(motif_points "${preset}"); do
		shows_motif "$(motif_pixel "${image}" "${side}" "${point%,*}" "${point#*,}")" "${paper}" "${colour}" || return 1
	done
}

# Succeed when the tag tree has a Document and no decoration, and the text has
# no motif glyph.
decoration_is_artefact() {
	local struct="${output%.pdf}.struct"
	pdfinfo -struct-text "${output}" >"${struct}"
	[ -s "${struct}" ] && grep -qE '^Document' "${struct}" &&
		! grep -qE 'Figure|Artifact|Shape' "${struct}" &&
		! pdf_page_text "${output}" 1 | grep -qE '[■□▲△●○◆◇]'
}

# Succeed when the Typst library and the SVG files draw the same motifs.
motif_geometry_match() {
	local name typst_lines svg_lines
	typst_lines="$(typst_motif_shapes || true)"
	[ -n "${typst_lines}" ] || return 1
	for name in facets steps ribbon dots; do
		svg_lines="$(svg_motif_shapes "${name}" "${ext_dir}/html/motifs/${name}.svg" 2>/dev/null || true)"
		[ -n "${svg_lines}" ] || return 1
		[ "$(grep "^${name} " <<<"${typst_lines}")" = "${svg_lines}" ] || return 1
	done
}

# Succeed when every slots( call of the Typst source has left:, centre: and right: only.
slots_three_only() {
	local calls line
	calls="$(grep -E '^[[:space:]]*[^/[:space:]].*slots\(' "${typ}" | grep -vF '#let slots(' || true)"
	[ "$(grep -c . <<<"${calls}")" -ge 2 ] || return 1
	while IFS= read -r line; do
		[ -n "${line}" ] || continue
		[ "$(grep -oE '[a-z-]+: ' <<<"${line#*slots(}" | tr -d ' ' | tr '\n' ' ')" = "left: centre: right: " ] || return 1
	done <<<"${calls}"
}

# Succeed when the page 2 footer reads 'Test Author | Version 1.2 | 2 / <total>'.
page_number_format() {
	local total footer
	total="$(pdf_page_count "${output}")"
	footer="$(pdf_footer "${output}" 2)"
	# The layout mode of pdftotext drops the narrow spaces around the slash,
	# so the number is read from the text in content stream order.
	[ "${total}" -ge 3 ] && grep -qE "^[[:space:]]*Test Author[[:space:]]+Version 1\.2[[:space:]]+2 ?/ ?${total}[[:space:]]*$" <<<"${footer}" &&
		pdftotext -raw -f 2 -l 2 "${output}" - | tr -d '\f' | grep -qE "(^| )2 / ${total}$"
}

# Succeed when the page 3 header has the title and a chapter, and page 1 has no header.
report_header() {
	pdf_header "${output}" 3 | grep -qE '^[[:space:]]*Survival analysis[[:space:]]+(Study design|Results)[[:space:]]*$' &&
		! pdf_header "${output}" 1 | grep -qE 'Survival analysis[[:space:]]+[A-Z]'
}

# Succeed when the PDF identifies as PDF/UA-1 and veraPDF finds no failure.
pdfua_default() {
	pdfinfo -meta "${output}" | grep -qE 'pdfuaid:part(>|=")1' && verapdf_ua1 "${output}"
}

# Check the report document of one preset.
# $1 preset.
check_report() {
	local preset="$1"
	find_verapdf
	expect "decoration-artefact-${preset}" "a tag tree without decoration, no motif glyph, and veraPDF ua1 compliance" \
		decoration_is_artefact
	expect "decoration-artefact-ua1-${preset}" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	expect "motif-corner-${preset}" "the ${preset} motif colour at the motif points $(motif_points "${preset}") of page 1" \
		motif_corner "${preset}"
	if [ "${preset}" = gold ]; then
		expect "page-number-format" "the page 2 footer 'Test Author | Version 1.2 | 2 / <total>'" page_number_format
		expect "report-header" "the page 3 header 'Survival analysis | | <chapter>', and no header on page 1" report_header
		expect "pdfua-default" "a PDF/UA-1 identification and no veraPDF ua1 failure" pdfua_default
		expect "slots-three-only" "every slots( call of the Typst output with left:, centre: and right: only" slots_three_only
		expect "motif-geometry-match" "the same shapes, points and opacities in typst/lib/motifs.typ and html/motifs/<name>.svg" \
			motif_geometry_match
	fi
}

# Succeed when the footer has the version and the page numbers, with no leading separator.
furniture_missing_metadata() {
	pdf_footer "${output}" 1 | grep -qE '^[[:space:]]*Version 1\.2[[:space:]]+1 ?/ ?1[[:space:]]*$'
}

# Succeed when the page 2 header holds the centre slot text.
centre_in_header() {
	pdf_header "${output}" 2 | grep -qF 'Middle slot'
}

# Succeed when the document in a subdirectory has its fonts and its motif.
subdir_assets() {
	local image side paper colour
	pdffonts "${output}" | grep -q 'SourceSerif4' || return 1
	image="$(page1_image)"
	side="$(motif_side_px)"
	paper="$(hex_rgb "$(preset_value gold light paper)")"
	colour="$(hex_rgb "$(preset_value gold light accent)")"
	shows_motif "$(motif_pixel "${image}" "${side}" 99.5 0.5)" "${paper}" "${colour}"
}

case "${1:-}" in
report) check_report "${2:?report needs a preset}" ;;
report-no-author)
	expect "furniture-missing-metadata" "the footer 'Version 1.2 | 1 / 1' with no leading separator" furniture_missing_metadata
	;;
center-alias)
	expect "center-alias" "header.center 'Middle slot' in the centre slot of the page 2 header" centre_in_header
	;;
subdir)
	expect "subdir-assets" "Source Serif 4 and the motif on page 1 of a document in a subdirectory" subdir_assets
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
