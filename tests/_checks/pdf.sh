#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the layout of a Typst PDF, read from its text, its pixels and its tag tree.
#
# Usage: pdf.sh report <preset>
#        pdf.sh code-window <preset>
#        pdf.sh callout-label <preset>
#        pdf.sh report-no-author
#        pdf.sh center-alias
#        pdf.sh subdir
#        pdf.sh footer-et-al
#        pdf.sh running-header
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format pdf.sh
need pdftotext
need pdfinfo
need pdffonts
need pdftoppm

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

# Succeed when the shapes on stdin, in the format of typst_motif_shapes, sit as
# the corner needs: facets, ribbon and steps touch the top edge (y = 0) and the
# right edge (x = 100), and dots keep the same clear space, above zero, at the
# top and at the right. A motif that breaks its rule is named on stderr.
motif_shapes_sit_in_corner() {
	awk '
		function abs(v) { return v < 0 ? -v : v }
		function note(name, x, y) {
			if (!(name in miny) || y < miny[name]) miny[name] = y
			if (!(name in maxx) || x > maxx[name]) maxx[name] = x
		}
		{
			name = $1; kind = $2
			if (kind == "circle") {
				note(name, $3 + $5, $4 - $5)
			} else if (kind == "rect") {
				note(name, $3 + $5, $4)
			} else {
				for (i = 3; i < NF - 1; i += 2) note(name, $i, $(i + 1))
			}
		}
		END {
			status = (length(miny) == 0)
			for (name in miny) {
				top = miny[name]; right = 100 - maxx[name]
				if (name == "dots") ok = (top > 1e-6 && abs(top - right) < 1e-6)
				else ok = (abs(top) < 1e-6 && abs(right) < 1e-6)
				if (!ok) {
					printf "%s: space at the top = %s, space at the right = %s\n", name, top, right > "/dev/stderr"
					status = 1
				}
			}
			exit status
		}'
}

# Succeed when every motif sits in the corner as its rule says, in the Typst
# library and in the SVG files.
motif_corner_space() {
	local name
	typst_motif_shapes | motif_shapes_sit_in_corner || return 1
	for name in facets steps ribbon dots; do
		svg_motif_shapes "${name}" "${ext_dir}/html/motifs/${name}.svg" | motif_shapes_sit_in_corner || return 1
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
		expect "motif-corner-space" "facets, ribbon and steps touching the top and right edges, and dots with equal clear space at the top and the right, in typst/lib/motifs.typ and html/motifs/<name>.svg" \
			motif_corner_space
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

# Succeed when the page 1 footer reads 'First Author et al. | Version 1.2 | 1 / <total>' on one line.
footer_et_al() {
	pdf_footer "${output}" 1 | grep -qE '^[[:space:]]*First Author et al\.[[:space:]]+Version 1\.2[[:space:]]+1 ?/ ?[0-9]+[[:space:]]*$'
}

# Succeed when the page on which chapter Beta starts below the top has Alpha in its header, and the
# next page has Beta.
running_header_in_force() {
	local page total lines
	total="$(pdf_page_count "${output}")"
	for ((page = 1; page <= total; page++)); do
		lines="$(pdf_page_text "${output}" "${page}" | grep -v '^[[:space:]]*$')"
		if grep -qE '^[[:space:]]*Beta[[:space:]]*$' <<<"${lines}"; then
			[ "$(grep -nE '^[[:space:]]*Beta[[:space:]]*$' <<<"${lines}" | head -n 1 | cut -d: -f1)" -gt 3 ] &&
				pdf_header "${output}" "${page}" | grep -qE 'Survival analysis[[:space:]]+Alpha[[:space:]]*$' &&
				pdf_header "${output}" $((page + 1)) | grep -qE 'Survival analysis[[:space:]]+Beta[[:space:]]*$'
			return
		fi
	done
	return 1
}

# Answer the Typst test that the code-window theme of a preset must pass, in
# terms of t, the theme, and c, the tokens: the traffic lights at 0.7em, as in
# HTML and Reveal.js, the file name in the muted colour, and the frame and the
# title bar of the preset, and the tint behind the code, all from the tokens.
# $1 preset.
code_window_theme_test() {
	printf 't.traffic-light-size == 0.7em and t.traffic-light-gap == 0.35em and t.label == c.muted and t.muted == c.muted and t.fill == c.tint and t.stroke-thickness == 0.75pt and '
	case "$1" in
	gold) printf 'type(t.stroke.top.paint) == gradient and t.stroke.top.paint.stops().map(s => s.at(0)) == (c.at("accent-low"), c.at("accent-high"), c.at("accent-low")) and t.stroke.top.thickness == 1.5pt and t.stroke.rest == 0.75pt + c.line and t.surface == c.tint and t.radius == 5pt' ;;
	mono) printf 't.stroke.top == 1.5pt + c.ink and t.stroke.rest == none and t.surface == c.tint and t.radius == 0pt' ;;
	quarto) printf 't.border == c.line and t.surface == color.mix((c.ink, 6%%), (c.tint, 94%%)) and t.radius == 6pt' ;;
	terminal) printf 't.border == c.line and t.at("stroke-dash", default: none) == none and t.surface == color.mix((c.ink, 6%%), (c.tint, 94%%)) and t.radius == 0pt' ;;
	esac
}

# Answer the value of a Typst expression evaluated in the laid-out document of
# the kept Typst file, so it can read a state at the location of an element.
# Fails on an error or a warning.
# $1 expression.
typst_in_document() {
	local value
	value="$(QUARTO_LOG_LEVEL=INFO quarto typst eval --in "${typ}" --root / --font-path "${ext_dir}/fonts" "$1" 2>&1)" || {
		printf '# %s\n' "${value}"
		return 1
	}
	value="$(drop_typst_downloads <<<"${value}")"
	if grep -qE '^(error|warning)' <<<"${value}"; then
		printf '# %s\n' "${value}"
		return 1
	fi
	printf '%s\n' "${value}"
}

# Succeed when both code windows of the document read a code-window theme
# that passes the test of the preset, at their own location in the laid-out
# document: the window with "coxph" and the window with "print". A theme set
# after a window, or not at all, fails. Prints the theme each window reads
# when the test fails.
# $1 preset.
code_window_theme() {
	local at result
	at='state("code-window-theme", (:)).at(query(raw.where(text: word)).first().location())'
	result="$(typst_in_document "{ import \"${typ}\": mc-tokens; let c = mc-tokens; (\"coxph\", \"print\").map(word => { let t = ${at}; t.len() > 0 and $(code_window_theme_test "$1") }) }")" || {
		printf '%s\n' "${result}"
		return 1
	}
	[ "${result}" = '[true,true]' ] || {
		typst_in_document "{ (\"coxph\", \"print\").map(word => repr(${at})) }" | sed 's/^/# theme at the windows: /'
		return 1
	}
}

# Succeed when the code of both windows sits inside a window for code-window,
# and the code of the block with no window does not: the highlighted code
# drops its own frame only inside a window, so the window frame is the only
# edge there.
code_window_body_frame() {
	local result
	result="$(typst_in_document '("coxph", "print", "nrow").map(word => state("cw-in-window", false).at(query(raw.where(text: word)).first().location()))')" || {
		printf '%s\n' "${result}"
		return 1
	}
	[ "${result}" = '[true,true,false]' ] || {
		printf '# inside a window, for coxph, print and nrow: %s\n' "${result}"
		return 1
	}
}

# Succeed when the capital letters of the callout label sit in the middle of
# its icon on page 1, within 0.4 pt. The page is read at 600 dpi in the 40 pt
# above the first word of the callout body ("Hazard"): the icon is the first
# group of columns in the icon colour, the label the pixels in the label colour
# to its right, and rows that a frame edge crosses are left out.
# $1 preset.
callout_label_centred() {
	local scheme=light body top dir
	[ "$1" = terminal ] && scheme=dark
	body="$(pdftotext -bbox -f 1 -l 1 "${output}" - | sed -n 's/.*yMin="\([0-9.]*\)".*>Hazard<.*/\1/p' | head -n 1)"
	[ -n "${body}" ] || {
		printf '# no callout body found\n'
		return 1
	}
	# Only the band above the body, 40 pt high and 4 in wide from the left edge.
	top="$(awk -v y="${body}" 'BEGIN { printf "%d", y * 600 / 72 - 333 }')"
	dir="$(mktemp -d)"
	pdftoppm -r 600 -f 1 -l 1 -x 0 -y "${top}" -W 2400 -H 333 -singlefile "${output}" "${dir}/band"
	python3 -I - "${dir}/band.ppm" \
		"$(preset_value "$1" "${scheme}" "$(case "$1" in gold | mono) echo note ;; *) echo note-text ;; esac)")" \
		"$(preset_value "$1" "${scheme}" note-text)" <<'PY'
import sys

path, ring_hex, text_hex = sys.argv[1:4]
with open(path, "rb") as handle:
    data = handle.read()
parts = data.split(b"\n", 3)
width, height = map(int, parts[1].split())
pixels = parts[3]

def rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))

def matcher(colour):
    def near(x, y):
        i = (y * width + x) * 3
        return sum(abs(pixels[i + k] - colour[k]) for k in range(3)) < 80
    return near

ring_near, text_near = matcher(rgb(ring_hex)), matcher(rgb(text_hex))

def edge_row(y):
    return sum(ring_near(x, y) for x in range(0, width, 8)) > width / 8 * 0.3

band = [y for y in range(0, height, 2) if not edge_row(y)]
# Every third row is enough to find the columns of the icon and the label.
columns = sorted({x for x in range(width) for y in band[::3] if ring_near(x, y)})
if not columns:
    sys.exit("# no icon found")
groups = []
for x in columns:
    if groups and x - groups[-1][1] <= 6:
        groups[-1][1] = x
    else:
        groups.append([x, x])
# A frame edge or a start bar runs down to the body; the icon stops above it.
# The last three rows of the band touch the body, and only edges reach them.
low = band[-3:]
icon = next((g for g in groups if not any(ring_near(x, y) for x in range(g[0], g[1] + 1) for y in low)), None)
if icon is None:
    sys.exit("# no icon found")
left, right = icon
ring_rows = [y for y in band if any(ring_near(x, y) for x in range(left, right + 1))]
text_rows = [y for y in band if any(text_near(x, y) for x in range(right + 8, min(width, right + 1200), 2))]
if not ring_rows or not text_rows:
    sys.exit("# no icon or no label rows")
offset = ((text_rows[0] + text_rows[-1]) - (ring_rows[0] + ring_rows[-1])) / 2 * 72 / 600
print("# label middle minus icon middle: %.2f pt" % offset)
sys.exit(0 if abs(offset) <= 0.4 else 1)
PY
	local status=$?
	rm -rf "${dir}"
	return "${status}"
}

# Succeed when the title in the metadata of the PDF is a given text.
# $1 title.
doc_title() {
	local title
	title="$(pdfinfo "${output}" | sed -n 's/^Title:[[:space:]]*//p')"
	[ "${title}" = "$1" ] || {
		printf '# title: %s\n' "${title}"
		return 1
	}
}

case "${1:-}" in
doc-title)
	find_verapdf
	expect "doc-title" "the PDF title '${2:?doc-title needs a title}'" doc_title "$2"
	expect "doc-title-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
code-window)
	find_verapdf
	expect "typst-code-window-theme-${2:?code-window needs a preset}" "the traffic lights and the ${2} frame and title bar from the tokens, see code_window_theme_test" \
		code_window_theme "$2"
	expect "typst-code-window-body-frame-${2}" "the code drops its own frame inside a window, and keeps it outside" code_window_body_frame
	expect "typst-code-window-ua1-${2}" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
callout-label)
	expect "typst-callout-label-align-${2:?callout-label needs a preset}" "the capital letters of the callout label in the middle of its icon" \
		callout_label_centred "$2"
	;;
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
footer-et-al)
	expect "footer-et-al" "the page 1 footer 'First Author et al. | Version 1.2 | 1 / <total>' on one line" footer_et_al
	;;
running-header)
	expect "running-header-in-force" "Alpha in the header of the page where Beta starts below the top, and Beta on the next page" \
		running_header_in_force
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
