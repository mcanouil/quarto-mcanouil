#!/usr/bin/env bash
set -euo pipefail

# Render checks for the mcanouil extension.
#
# Each check is a function named check_<name> that renders fixtures and reads
# facts off the output. To add a check, define the function and list its name
# in CHECKS. Quarto does not follow symbolic links, so the extension is copied
# into a temporary work directory.
#
# Requires: quarto, pdftotext, pdfinfo, pdffonts and pdftoppm from poppler,
# and docker for the veraPDF checks of tests/a11y/run.sh.
#
# Usage: tests/run.sh [--only <glob>]

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "${tests_dir}")"

only='*'
if [ "${1:-}" = "--only" ]; then
	only="${2:?--only needs a glob}"
fi

work_dir="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "${work_dir}"' EXIT

cp -R "${repo_dir}/_extensions" "${work_dir}/_extensions"
cp -R "${tests_dir}/fixtures/." "${work_dir}/"
cp -R "${tests_dir}/projects" "${work_dir}/projects"

passed=0
failed=0

# Report one check and count it.
# $1 outcome, "pass" or "fail". $2 name. $3 what the check expected.
report() {
	if [ "$1" = "pass" ]; then
		passed=$((passed + 1))
		printf 'pass  %s\n' "$2"
	else
		failed=$((failed + 1))
		printf 'FAIL  %s\n' "$2"
		printf '      expected %s\n' "$3"
	fi
}

# Answer the file extension a format renders to.
# $1 format, html, typst or revealjs.
output_extension() {
	case "$1" in
	typst) printf 'pdf' ;;
	*) printf 'html' ;;
	esac
}

# Answer the stderr lines of a render that are not Quarto progress. Quarto
# writes these progress lines to stderr, and --quiet cannot be used because it
# also drops warnings:
#   - blank lines;
#   - the "pandoc" and "metadata" headers, which are bold escape sequences;
#   - the indented lines of the resolved pandoc options and metadata;
#   - "[typst]: Compiling ... DONE";
#   - "[verapdf]: Validating ... against PDF/UA1...PASSED", with a green
#     PASSED, and the colour reset that follows it on its own line;
#   - "Output created: <file>".
# Anything else, a "WARN:" or "ERROR:" line, a failed veraPDF validation or a
# filter message, is a problem.
# $1 stderr file.
unexpected_stderr() {
	grep -Ev $'^$|^\033\\[1m(pandoc|metadata)|^[[:space:]]|^\\[typst\\]: Compiling .*DONE$|^\\[verapdf\\]: Validating .* against PDF/UA1\\.\\.\\.\033\\[32mPASSED$|^\033\\[39m$|^Output created: ' "$1" || true
}

# Render a fixture once, without a check of its stderr, and answer the path of
# the output file. The stderr goes to <output without extension>.err. The
# fixture can be in a subdirectory, which is then the working directory, so
# Quarto finds the _brand.yml beside it; Quarto only looks for extensions
# beside a fixture, so the extension is copied there too. Quarto names a kept
# .typ file after the input, so it is renamed after the output.
# $1 fixture path without extension, relative to tests/fixtures.
# $2 format, html, typst or revealjs. $3 preset base name.
render_raw() {
	local dir base name output
	dir="${work_dir}/$(dirname "$1")"
	base="$(basename "$1")"
	name="${base}-$2-$3"
	output="${dir}/${name}.$(output_extension "$2")"
	if [ ! -f "${output}" ]; then
		if [ ! -d "${dir}/_extensions" ]; then
			cp -R "${repo_dir}/_extensions" "${dir}/_extensions"
		fi
		if ! (cd "${dir}" && quarto render "${base}.qmd" --to "mcanouil-$2" \
			--metadata-file "${tests_dir}/presets/$3.yml" \
			--output "${name}.$(output_extension "$2")" \
			>"${dir}/${name}.out" 2>"${dir}/${name}.err"); then
			printf 'FAIL  %s: the render failed\n' "$1-$2-$3" >&2
			grep -v "^    at" "${dir}/${name}.err" >&2
			exit 1
		fi
		if [ -f "${dir}/${base}.typ" ]; then
			mv "${dir}/${base}.typ" "${dir}/${name}.typ"
		fi
	fi
	printf '%s' "${output}"
}

# Render a fixture once, and answer the path of the output file. A render with
# any other stderr output counts as a failure, and stops the run.
# $1 fixture path without extension. $2 format, html, typst or revealjs.
# $3 preset base name.
render() {
	local output
	output="$(render_raw "$1" "$2" "$3")"
	if [ -n "$(unexpected_stderr "${output%.*}.err")" ]; then
		printf 'FAIL  %s: the render wrote to stderr\n' "$1-$2-$3" >&2
		unexpected_stderr "${output%.*}.err" >&2
		exit 1
	fi
	printf '%s' "${output}"
}

# Render a fixture with every preset, and fill the RENDERED array with one
# output path per preset. It runs in the main shell, so a failed render stops
# the run.
# $1 fixture base name. $2 format, html, typst or revealjs.
render_all_presets() {
	local preset output
	RENDERED=()
	for preset in "${tests_dir}"/presets/*.yml; do
		output="$(render "$1" "$2" "$(basename "${preset}" .yml)")"
		RENDERED+=("${output}")
	done
}

# Answer the text of a PDF, with the layout kept.
# $1 PDF file.
pdf_text() {
	pdftotext -layout "$1" -
}

# Answer the page count of a PDF.
# $1 PDF file.
pdf_page_count() {
	pdfinfo "$1" | awk '/^Pages:/ { print $2 }'
}

# Succeed when a file holds a fixed string.
# $1 file. $2 string.
has() {
	grep -qF -- "$2" "$1"
}

# Succeed when a file lacks a fixed string.
# $1 file. $2 string.
lacks() {
	! grep -qF -- "$2" "$1"
}

# Count the lines of a file that hold a fixed string.
# $1 file. $2 string.
count() {
	grep -cF -- "$2" "$1" || true
}

# Report that one embedded tool ran, from the outcome of a command.
# $1 tool name. The rest is the command that succeeds when the tool ran.
tool_active() {
	local name="$1"
	shift
	if "$@"; then
		report pass "tool-${name}-active" ""
	else
		report fail "tool-${name}-active" "the marker '${*: -1}' of ${name} in the output of tests/fixtures/tools.qmd"
	fi
}

# Succeed when a file holds a fixed string on exactly two lines.
# $1 file. $2 string.
twice() {
	[ "$(count "$1" "$2")" = 2 ]
}

# Succeed when the text of a PDF holds a fixed string on exactly two lines.
# $1 PDF file. $2 string.
pdf_twice() {
	[ "$(pdf_text "$1" | grep -cF -- "$2" || true)" = 2 ]
}

# Succeed when the table of contents of an HTML file lacks a link target.
# $1 file. $2 link target, for example "#section".
toc_lacks() {
	has "$1" 'id="TOC"' && lacks "$1" "href=\"$2\" id=\"toc-"
}

# Answer the value of a token in a preset file of the extension.
# $1 preset name. $2 scheme, light or dark. $3 token.
preset_value() {
	awk -v mode="$2:" -v token="  $3:" '
		/^[^ #]/ { in_mode = ($1 == mode) }
		in_mode && index($0, token) == 1 { gsub(/[" ]/, "", $2); print $2; exit }
	' "${repo_dir}/_extensions/mcanouil/presets/$1.yml"
}

# Answer the one-line CSS rule of a selector in an HTML file.
# $1 file. $2 selector, as written before the opening brace.
css_rule() {
	grep -F -- "$2 {" "$1" | head -n 1
}

# Succeed when a Typst source holds a token with a colour.
# $1 PDF file, beside its kept .typ file. $2 token. $3 hex colour.
typ_token() {
	has "${1%.pdf}.typ" "$2: rgb(\"$3\")"
}

# Succeed when the light rules of an HTML document, the :root rule of a
# Reveal.js deck, or the token dictionary of a Typst file hold a token with
# a colour.
# $1 output file. $2 format. $3 token. $4 hex colour.
reaches() {
	local value="--mc-$3: $4;"
	case "$2" in
	html) css_rule "$1" 'body.quarto-light' | grep -qF -- "${value}" ;;
	revealjs) css_rule "$1" ':root' | grep -qF -- "${value}" ;;
	typst) typ_token "$1" "$3" "$4" ;;
	esac
}

# Answer the text of one page of a PDF, with the layout kept.
# $1 PDF file. $2 page number.
pdf_page_text() {
	pdftotext -layout -f "$2" -l "$2" "$1" -
}

# Answer the last line of a page of a PDF that holds text: the footer.
# $1 PDF file. $2 page number.
pdf_footer() {
	pdf_page_text "$1" "$2" | grep -v '^[[:space:]]*$' | tail -n 1
}

# Answer the first line of a page of a PDF that holds text: the header.
# $1 PDF file. $2 page number.
pdf_header() {
	pdf_page_text "$1" "$2" | grep -v '^[[:space:]]*$' | head -n 1
}

# Render page 1 of a PDF to a PPM image at 50 dpi, once, and answer its path.
# $1 PDF file.
page1_image() {
	local image="${1%.pdf}-page1"
	if [ ! -f "${image}.ppm" ]; then
		pdftoppm -r 50 -f 1 -l 1 -singlefile "$1" "${image}"
	fi
	printf '%s.ppm' "${image}"
}

# Answer the width and height of a binary PPM image.
# $1 PPM file.
ppm_size() {
	LC_ALL=C sed -n 2p "$1"
}

# Answer the red, green and blue values of one pixel of a binary PPM image,
# whose header is "P6", the size and "255" on three lines.
# $1 PPM file. $2 x. $3 y.
pixel() {
	local width height header
	read -r width height <<<"$(ppm_size "$1")"
	header=$((3 + ${#width} + 1 + ${#height} + 1 + 4))
	od -An -tu1 -j $((header + ($3 * width + $2) * 3)) -N 3 "$1" | awk 'NF { print $1, $2, $3 }'
}

# Answer the red, green and blue values of a hex colour.
# $1 colour, "#rrggbb".
hex_rgb() {
	printf '%d %d %d' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"
}

# Answer the distance of two colours, as the sum of the channel differences.
# $1 and $2 colours, "r g b".
colour_distance() {
	awk -v a="$1" -v b="$2" 'BEGIN {
		split(a, x, " "); split(b, y, " "); d = 0
		for (i = 1; i <= 3; i++) { v = x[i] - y[i]; d += (v < 0 ? -v : v) }
		print d
	}'
}

# Succeed when a pixel shows the motif: it differs from the paper, and it is
# closer to the motif colour than the paper is.
# $1 pixel, "r g b". $2 paper, "r g b". $3 motif colour, "r g b".
shows_motif() {
	local from_paper to_colour paper_to_colour
	from_paper="$(colour_distance "$1" "$2")"
	to_colour="$(colour_distance "$1" "$3")"
	paper_to_colour="$(colour_distance "$2" "$3")"
	[ "${from_paper}" -gt 8 ] && [ "${to_colour}" -lt "${paper_to_colour}" ]
}

# Answer the value of a Typst expression that uses a top-level binding of a
# kept Typst file. `typst eval --in` does not give the scope of the file, so the
# expression imports the binding. `quarto typst` writes the value to stderr, so
# both streams are read, and any diagnostic fails.
# $1 kept Typst file, absolute. $2 binding name. $3 expression.
typst_value() {
	local value
	value="$(quarto typst eval "{ import \"$1\": $2; $3 }" --root / 2>&1)" || return 1
	if grep -qE '^(error|warning)' <<<"${value}"; then
		printf '%s\n' "${value}" >&2
		return 1
	fi
	printf '%s\n' "${value}"
}

# Answer the side of the page 1 motif of a rendered PDF, in pixels at 50 dpi,
# from the motif size that the kept Typst file uses.
# $1 PDF file.
motif_side_px() {
	local points
	points="$(typst_value "${1%.pdf}.typ" mc-first-page-motif-size 'mc-first-page-motif-size.pt()' || printf 0)"
	awk -v p="${points}" 'BEGIN { printf "%d", p * 50 / 72 }'
}

# Answer the pixel of a page 1 image at a point of the top right motif, given
# in motif units (the 100 by 100 view box). The last column and the first row
# of the image are only partly on the page, so the point is kept off them.
# $1 PPM file. $2 motif side in pixels. $3 motif x. $4 motif y.
motif_pixel() {
	local width height x y
	read -r width height <<<"$(ppm_size "$1")"
	x="$(awk -v w="${width}" -v s="$2" -v m="$3" 'BEGIN { x = int(w - (100 - m) / 100 * s); if (x > w - 2) x = w - 2; print x }')"
	y="$(awk -v s="$2" -v m="$4" 'BEGIN { y = int(m / 100 * s); if (y < 1) y = 1; print y }')"
	pixel "$1" "${x}" "${y}"
}

# Answer the shapes of the motifs of the Typst library, one line each:
# "<motif> <kind> <numbers...> <opacity>".
# $1 kept Typst file of a render.
typst_motif_shapes() {
	typst_value "$1" mc-motif-lines 'mc-motif-lines().join("\n")' | sed -E 's/^"//; s/"$//' | sed 's/\\n/\n/g'
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

check_smoke_renders() {
	local file ok=1
	render_all_presets smoke typst
	for file in "${RENDERED[@]}"; do
		[ "$(pdf_page_count "${file}")" = "1" ] || ok=0
	done
	render_all_presets smoke html
	for file in "${RENDERED[@]}"; do
		has "${file}" '<main' || ok=0
	done
	render_all_presets smoke revealjs
	for file in "${RENDERED[@]}"; do
		[ -s "${file}" ] || ok=0
	done
	if [ "${ok}" = 1 ]; then
		report pass smoke-renders ""
	else
		report fail smoke-renders "one PDF page, <main in the HTML, and a revealjs file"
	fi
}

check_tool_active() {
	local html revealjs typst
	html="$(render tools html gold)"
	revealjs="$(render tools revealjs gold)"
	typst="$(render tools typst gold)"
	tool_active offset-headings has "${html}" '<section id="offset" class="level3">'
	tool_active div-reuse twice "${html}" '<p>Reusable content.</p>'
	tool_active toc-depth toc_lacks "${html}" '#hidden-from-contents'
	tool_active highlight-text has "${html}" 'class="light-content"'
	tool_active iconify has "${html}" '<iconify-icon'
	tool_active prism has "${html}" 'data-prism="yes"'
	tool_active code-window has "${html}" 'sourceCode python cw-auto'
	tool_active veil has "${revealjs}" 'data-veil-hidden'
	tool_active veil-plugin has "${revealjs}" 'RevealVeil'
	tool_active typst-render has "${html}" 'assets/typst-render/'
	tool_active gitlink has "${html}" 'gitlink-badge'
	tool_active mobile-toc has "${html}" 'mobile-toc/mobile-toc.css'
	tool_active cascade twice "${revealjs}" '<h2>Cascade</h2>'
	tool_active codefrag has "${revealjs}" 'RevealJsCodefrag'
	tool_active tabset has "${revealjs}" 'RevealJsTabset'
	tool_active div-reuse-typst pdf_twice "${typst}" 'Reusable content.'
}

check_tool_optin_off() {
	local file ok=1
	for file in "$(render tools html gold)" "$(render tools revealjs gold)"; do
		lacks "${file}" 'preview-colour' || ok=0
		lacks "${file}" 'collapse-output' || ok=0
		lacks "${file}" 'quarto-remember' || ok=0
	done
	if [ "${ok}" = 1 ]; then
		report pass tool-optin-off ""
	else
		report fail tool-optin-off "no preview-colour, collapse-output or remember marker without their options"
	fi
}

check_tool_quiet() {
	local file marker ok=1
	for file in "$(render smoke html gold)" "$(render smoke revealjs gold)"; do
		for marker in 'class="light-content"' '<iconify-icon' 'data-prism=' 'sourceCode python cw-auto' \
			'data-veil-hidden' 'assets/typst-render/' 'gitlink-badge' 'mobile-toc/' 'preview-colour' \
			'collapse-output' 'quarto-remember'; do
			lacks "${file}" "${marker}" || ok=0
		done
	done
	if [ "${ok}" = 1 ]; then
		report pass tool-quiet ""
	else
		report fail tool-quiet "no tool marker in the output of tests/fixtures/smoke.qmd"
	fi
}

check_tool_remember_optin() {
	local file
	file="$(render remember html gold)"
	if has "${file}" 'quarto-remember'; then
		report pass tool-remember-optin ""
	else
		report fail tool-remember-optin "the marker 'quarto-remember' in the output of tests/fixtures/remember.qmd"
	fi
}

check_preset_reaches() {
	local preset format output expected
	for preset in gold mono quarto terminal; do
		expected="$(preset_value "${preset}" light accent-text)"
		for format in html revealjs typst; do
			output="$(render smoke "${format}" "${preset}")"
			if reaches "${output}" "${format}" accent-text "${expected}"; then
				report pass "preset-${preset}-reaches-${format}" ""
			else
				report fail "preset-${preset}-reaches-${format}" "accent-text ${expected} of ${preset} in the ${format} output"
			fi
		done
	done
}

check_preset_select_mono() {
	local format output mono gold ok=1
	mono="$(preset_value mono light accent-text)"
	gold="$(preset_value gold light accent-text)"
	for format in html revealjs typst; do
		output="$(render smoke "${format}" mono)"
		reaches "${output}" "${format}" accent-text "${mono}" || ok=0
		! reaches "${output}" "${format}" accent-text "${gold}" || ok=0
	done
	if [ "${ok}" = 1 ]; then
		report pass preset-select-mono ""
	else
		report fail preset-select-mono "mono accent-text ${mono}, and not gold ${gold}, in all three formats"
	fi
}

check_preset_default_gold() {
	local output ok=1 expected
	expected="$(preset_value gold light accent-text)"
	if grep -q 'preset' "${tests_dir}/presets/gold.yml"; then
		ok=0
	fi
	for format in html revealjs typst; do
		output="$(render smoke "${format}" gold)"
		reaches "${output}" "${format}" accent-text "${expected}" || ok=0
	done
	if [ "${ok}" = 1 ]; then
		report pass preset-default-gold ""
	else
		report fail preset-default-gold "gold accent-text ${expected} in all three formats when no preset is set"
	fi
}

check_reveal_dark_tokens() {
	local output ok=1 token
	output="$(render dark-deck revealjs gold)"
	for token in paper ink accent-text; do
		reaches "${output}" revealjs "${token}" "$(preset_value gold dark "${token}")" || ok=0
	done
	css_rule "${output}" '.reveal .slides section.dark, .reveal .slides section.mc-ground' |
		grep -qF -- "--mc-paper: $(preset_value gold dark paper);" || ok=0
	if [ "${ok}" = 1 ]; then
		report pass reveal-dark-tokens ""
	else
		report fail reveal-dark-tokens "the gold dark tokens in :root of a brand-mode: dark deck, and in the dark and ground slide rule"
	fi
}

check_html_dark_tokens() {
	local output ok=1 preset
	for preset in gold terminal; do
		output="$(render smoke html "${preset}")"
		css_rule "${output}" 'body.quarto-dark' | grep -qF -- "--mc-paper: $(preset_value "${preset}" dark paper);" || ok=0
	done
	css_rule "$(render smoke html terminal)" 'body.quarto-light' |
		grep -qF -- "--mc-paper: $(preset_value terminal dark paper);" || ok=0
	has "${output}" 'quarto-color-alternate" id="quarto-bootstrap" data-mode="dark"' || ok=0
	if [ "${ok}" = 1 ]; then
		report pass html-dark-tokens ""
	else
		report fail html-dark-tokens "dark paper in body.quarto-dark, terminal dark paper in body.quarto-light, and a dark stylesheet that Quarto marks dark"
	fi
}

check_user_background_dark() {
	local output ok=1
	output="$(render user-background/background html gold)"
	css_rule "${output}" 'body.quarto-dark' | grep -qF -- '--mc-paper: #202020;' || ok=0
	css_rule "${output}" 'body.quarto-light' | grep -qF -- '--mc-paper: #ffffff;' || ok=0
	has "${output}" 'quarto-color-alternate" id="quarto-bootstrap" data-mode="dark"' || ok=0
	if [ "${ok}" = 1 ]; then
		report pass user-background-dark ""
	else
		report fail user-background-dark "user dark background in body.quarto-dark, and a dark stylesheet that Quarto marks dark"
	fi
}

check_link_token() {
	local output css ok=1
	output="$(render smoke html terminal)"
	css_rule "${output}" 'body.quarto-light' | grep -qF -- "--mc-link: $(preset_value terminal dark link);" || ok=0
	css="$(dirname "${output}")/$(grep -oE 'href="[^"]*bootstrap-[0-9a-f]+\.min\.css"' "${output}" | head -n 1 | sed -E 's/^href="(.*)"$/\1/')"
	[ -f "${css}" ] && grep -qF 'color:var(--mc-link)' "${css}" || ok=0
	typ_token "$(render smoke typst terminal)" link "$(preset_value terminal dark link)" || ok=0
	if [ "${ok}" = 1 ]; then
		report pass link-token ""
	else
		report fail link-token "terminal --mc-link $(preset_value terminal dark link) in HTML and Typst, and links coloured by var(--mc-link)"
	fi
}

check_no_sass_colour_fns() {
	local found
	# shellcheck disable=SC2016 # the $ in the pattern is a literal Sass variable prefix
	found="$(grep -rEn '(^|[^-[:alnum:]])(mix|lighten|darken|shade-color|tint-color)\([^;]*(\$mc-|var\(--mc-)' \
		"${repo_dir}/_extensions/mcanouil/html" "${repo_dir}/_extensions/mcanouil/revealjs" || true)"
	if [ -z "${found}" ]; then
		report pass no-sass-colour-fns ""
	else
		report fail no-sass-colour-fns "no Sass colour function on a preset token, found: ${found}"
	fi
}

check_terminal_light_warns() {
	local format output err warning='mcanouil: the terminal preset is dark only; brand-mode: light is ignored.' ok=1
	for format in html typst; do
		output="$(render_raw terminal-light "${format}" terminal)"
		err="${output%.*}.err"
		[ "$(grep -cF -- "${warning}" "${err}" || true)" = 1 ] || ok=0
		if unexpected_stderr "${err}" | grep -vqF -- "${warning}"; then
			ok=0
		fi
	done
	typ_token "$(render_raw terminal-light typst terminal)" paper "$(preset_value terminal dark paper)" || ok=0
	has "${output%.pdf}.typ" 'mode: "dark"' || ok=0
	if [ "${ok}" = 1 ]; then
		report pass terminal-light-warns ""
	else
		report fail terminal-light-warns "the warning '${warning}' once per render, and dark terminal tokens"
	fi
}

check_contrast_presets_pass() {
	local format ok=1
	for format in html revealjs typst; do
		render_all_presets smoke "${format}"
	done
	if [ "${ok}" = 1 ]; then
		report pass contrast-presets-pass ""
	else
		report fail contrast-presets-pass "all four presets to render in every format"
	fi
}

check_contrast_fail_message() {
	local dir="${work_dir}/bad-contrast" code=0 ratio message
	cp -R "${repo_dir}/_extensions" "${dir}/_extensions"
	(cd "${dir}" && quarto render bad.qmd --to mcanouil-html >bad.out 2>bad.err) || code=$?
	ratio="$(grep -oE 'accent-text on paper \(light\) is [0-9]+\.[0-9]{2}:1' "${dir}/bad.err" | head -n 1 | grep -oE '[0-9]+\.[0-9]{2}' || true)"
	message="mcanouil: contrast check failed: accent-text on paper (light) is ${ratio}:1, below 4.50:1. Change accent-text or paper in _brand.yml."
	if [ "${code}" != 0 ] && [ -n "${ratio}" ] && has "${dir}/bad.err" "${message}" && [ ! -f "${dir}/bad.html" ]; then
		report pass contrast-fail-message ""
	else
		report fail contrast-fail-message "a non-zero exit, no output, and the message '${message}'"
	fi
}

check_partial_user_brand() {
	local html typst ok=1 ground
	ground="$(preset_value gold light ground-1)"
	html="$(render user-brand/brand html gold)"
	typst="$(render user-brand/brand typst gold)"
	reaches "${html}" html accent '#ff0000' || ok=0
	reaches "${html}" html ground-1 "${ground}" || ok=0
	typ_token "${typst}" accent '#ff0000' || ok=0
	typ_token "${typst}" ground-1 "${ground}" || ok=0
	if [ "${ok}" = 1 ]; then
		report pass partial-user-brand ""
	else
		report fail partial-user-brand "user primary #ff0000 as accent, and preset ground-1 ${ground}, in HTML and Typst"
	fi
}

# Succeed when every @font-face URL of the fonts.css linked from an HTML file
# names a file that exists, and the file makes no request to a font service.
# $1 HTML file.
html_fonts_local() {
	local css url found=0
	css="$(grep -oE 'href="[^"]*fonts\.css"' "$1" | head -n 1 | sed -E 's/^href="(.*)"$/\1/')"
	[ -n "${css}" ] || return 1
	css="$(dirname "$1")/${css}"
	[ -f "${css}" ] || return 1
	while IFS= read -r url; do
		[ -f "$(dirname "${css}")/${url}" ] || return 1
		found=1
	done < <(grep -oE 'url\("[^"]+"\)' "${css}" | sed -E 's/^url\("(.*)"\)$/\1/')
	[ "${found}" = 1 ] && lacks "$1" 'fonts.googleapis' && lacks "$1" 'fonts.gstatic'
}

check_fonts_embedded() {
	local ok=1
	pdffonts "$(render smoke typst gold)" | grep -q 'SourceSerif4' || ok=0
	pdffonts "$(render smoke typst terminal)" | grep -q 'JetBrainsMono' || ok=0
	html_fonts_local "$(render smoke html gold)" || ok=0
	html_fonts_local "$(render smoke revealjs mono)" || ok=0
	css_rule "$(render smoke html mono)" 'body.quarto-light' | grep -qF -- '--mc-font-base: "Alegreya Sans", sans-serif;' || ok=0
	if [ "${ok}" = 1 ]; then
		report pass fonts-embedded ""
	else
		report fail fonts-embedded "Source Serif 4 and JetBrains Mono in the PDFs, local @font-face files, and --mc-font-base"
	fi
}

check_no_hex_outside_presets() {
	local dir found
	found=""
	for dir in lua typst html revealjs; do
		found+="$(grep -rEn '#[0-9a-fA-F]{3,8}\b' "${repo_dir}/_extensions/mcanouil/${dir}" || true)"
	done
	if [ -z "${found}" ]; then
		report pass no-hex-outside-presets ""
	else
		report fail no-hex-outside-presets "no hex colour outside presets/, found: ${found}"
	fi
}

check_label_en() {
	local typst
	typst="$(render labels-en typst gold)"
	if has "${typst%.pdf}.typ" 'mcanouil-in-this-chapter: "In this chapter"' &&
		has "${typst%.pdf}.typ" 'mcanouil-solution-page: "Solution: page {page}"'; then
		report pass label-en ""
	else
		report fail label-en "the English labels in the mc-labels dictionary of the Typst output"
	fi
}

check_label_fr() {
	local typst
	typst="$(render labels-fr typst gold)"
	if has "${typst%.pdf}.typ" 'mcanouil-in-this-chapter: "Dans ce chapitre"' &&
		lacks "${typst%.pdf}.typ" 'mcanouil-in-this-chapter: "In this chapter"'; then
		report pass label-fr ""
	else
		report fail label-fr "the French label 'Dans ce chapitre', and not the English one"
	fi
}

check_label_fallback() {
	local typst
	typst="$(render labels-es typst gold)"
	if has "${typst%.pdf}.typ" 'mcanouil-in-this-chapter: "In this chapter"'; then
		report pass label-fallback ""
	else
		report fail label-fallback "the English label for lang: es, with no warning"
	fi
}

check_label_override() {
	local typst
	typst="$(render labels-override/labels typst gold)"
	if has "${typst%.pdf}.typ" 'mcanouil-exercise: "Task"' &&
		has "${typst%.pdf}.typ" 'mcanouil-solution: "Solution"'; then
		report pass label-override ""
	else
		report fail label-override "the label 'Task' from the user language file, and the other labels unchanged"
	fi
}

check_no_label_text_outside_language_files() {
	local found
	found="$(grep -rEn 'In this chapter|Dans ce chapitre|Invoice number|Postscript' \
		"${repo_dir}/_extensions/mcanouil/lua" "${repo_dir}/_extensions/mcanouil/typst" || true)"
	if [ -z "${found}" ]; then
		report pass no-label-text-outside-language-files ""
	else
		report fail no-label-text-outside-language-files "no label text in lua/ or typst/, found: ${found}"
	fi
}

check_slots_three_only() {
	local typ calls ok=1 line
	typ="$(render report typst gold)"
	typ="${typ%.pdf}.typ"
	calls="$(grep -E '^[[:space:]]*[^/[:space:]].*slots\(' "${typ}" | grep -vF '#let slots(' || true)"
	[ "$(grep -c . <<<"${calls}")" -ge 2 ] || ok=0
	while IFS= read -r line; do
		[ -n "${line}" ] || continue
		[ "$(grep -oE '[a-z-]+: ' <<<"${line#*slots(}" | tr -d ' ' | tr '\n' ' ')" = "left: centre: right: " ] || ok=0
	done <<<"${calls}"
	if [ "${ok}" = 1 ]; then
		report pass slots-three-only ""
	else
		report fail slots-three-only "every slots( call of the Typst output with left:, centre: and right: only, found: ${calls}"
	fi
}

check_center_alias() {
	local output
	output="$(render center-alias typst gold)"
	if has "${output%.pdf}.typ" 'centre: [Middle slot]' && pdf_header "${output}" 2 | grep -qF 'Middle slot'; then
		report pass center-alias ""
	else
		report fail center-alias "header.center 'Middle slot' in the centre slot of the page 2 header"
	fi
}

check_page_number_format() {
	local output total footer
	output="$(render report typst gold)"
	total="$(pdf_page_count "${output}")"
	footer="$(pdf_footer "${output}" 2)"
	# The layout mode of pdftotext drops the narrow spaces around the slash,
	# so the number is read from the text in content stream order.
	if [ "${total}" -ge 3 ] && grep -qE "^[[:space:]]*Test Author[[:space:]]+Version 1\.2[[:space:]]+2 ?/ ?${total}[[:space:]]*$" <<<"${footer}" &&
		pdftotext -raw -f 2 -l 2 "${output}" - | tr -d '\f' | grep -qE "(^| )2 / ${total}$"; then
		report pass page-number-format ""
	else
		report fail page-number-format "the page 2 footer 'Test Author | Version 1.2 | 2 / ${total}', found '${footer}'"
	fi
}

check_report_header() {
	local output header
	output="$(render report typst gold)"
	header="$(pdf_header "${output}" 3)"
	if grep -qE '^[[:space:]]*Survival analysis[[:space:]]+(Study design|Results)[[:space:]]*$' <<<"${header}" &&
		! pdf_header "${output}" 1 | grep -qE 'Survival analysis[[:space:]]+[A-Z]'; then
		report pass report-header ""
	else
		report fail report-header "the page 3 header 'Survival analysis | | <chapter>', and no header on page 1, found '${header}'"
	fi
}

check_furniture_missing_metadata() {
	local output footer
	output="$(render report-no-author typst gold)"
	footer="$(pdf_footer "${output}" 1)"
	if grep -qE '^[[:space:]]*Version 1\.2[[:space:]]+1 ?/ ?1[[:space:]]*$' <<<"${footer}"; then
		report pass furniture-missing-metadata ""
	else
		report fail furniture-missing-metadata "the footer 'Version 1.2 | 1 / 1' with no leading separator, found '${footer}'"
	fi
}

check_pdfua_default() {
	local output ok=1
	output="$(render report typst gold)"
	pdfinfo -meta "${output}" | grep -qE 'pdfuaid:part(>|=")1' || ok=0
	"${tests_dir}/a11y/run.sh" pdf "${output}" >"${output%.pdf}.verapdf" 2>&1 || ok=0
	if [ "${ok}" = 1 ]; then
		report pass pdfua-default ""
	else
		report fail pdfua-default "a PDF/UA-1 identification and no veraPDF ua1 failure: $(tail -n 5 "${output%.pdf}.verapdf")"
	fi
}

check_decoration_artefact() {
	local preset output ok=1
	for preset in gold mono quarto terminal; do
		output="$(render report typst "${preset}")"
		pdfinfo -struct-text "${output}" >"${output%.pdf}.struct"
		[ -s "${output%.pdf}.struct" ] || ok=0
		! grep -qE 'Figure|Artifact|Shape' "${output%.pdf}.struct" || ok=0
		! pdf_page_text "${output}" 1 | grep -qE '[■□▲△●○◆◇]' || ok=0
		grep -qE '^Document' "${output%.pdf}.struct" || ok=0
		"${tests_dir}/a11y/run.sh" pdf "${output}" >/dev/null 2>&1 || ok=0
		has "${output%.pdf}.typ" 'motif(' || ok=0
	done
	if [ "${ok}" = 1 ]; then
		report pass decoration-artefact ""
	else
		report fail decoration-artefact "a motif call, a tag tree without decoration, no motif glyph in the text, and veraPDF ua1 compliance, in every preset"
	fi
}

# Motif sample points of each preset, in motif units: "x,y" pairs inside a
# shape. The first pair is the shape nearest the corner, the last one is on the
# right edge at mid motif height or the nearest shape to it.
declare -A MOTIF_POINTS=(
	[gold]="99.5,0.5 99.5,50"
	[mono]="99.5,0.5 81,0.5 99.5,32 99.5,50"
	[quarto]="46,0.5 99.5,54"
	[terminal]="98.7,1.3 98.7,50.3"
)

# Token of the colour that each preset motif uses on a light page; a dark
# page uses accent-high.
declare -A MOTIF_TOKEN=([gold]=accent [mono]=accent [quarto]=accent [terminal]=accent-high)

check_motif_corner() {
	local preset output image side mode paper colour point ok
	for preset in gold mono quarto terminal; do
		ok=1
		output="$(render report typst "${preset}")"
		image="$(page1_image "${output}")"
		side="$(motif_side_px "${output}")"
		mode=light
		[ "${preset}" = terminal ] && mode=dark
		paper="$(hex_rgb "$(preset_value "${preset}" "${mode}" paper)")"
		colour="$(hex_rgb "$(preset_value "${preset}" "${mode}" "${MOTIF_TOKEN[${preset}]}")")"
		[ "${side}" -gt 50 ] || ok=0
		for point in ${MOTIF_POINTS[${preset}]}; do
			shows_motif "$(motif_pixel "${image}" "${side}" "${point%,*}" "${point#*,}")" "${paper}" "${colour}" || ok=0
		done
		if [ "${ok}" = 1 ]; then
			report pass "motif-corner-${preset}" ""
		else
			report fail "motif-corner-${preset}" "the ${preset} motif colour at the motif points ${MOTIF_POINTS[${preset}]} of page 1"
		fi
	done
}

check_motif_geometry_match() {
	local typ name typst_lines svg_lines ok=1
	typ="$(render report typst gold)"
	typst_lines="$(typst_motif_shapes "${typ%.pdf}.typ" || true)"
	[ -n "${typst_lines}" ] || ok=0
	for name in facets steps ribbon dots; do
		svg_lines="$(svg_motif_shapes "${name}" "${repo_dir}/_extensions/mcanouil/html/motifs/${name}.svg" 2>/dev/null || true)"
		[ -n "${svg_lines}" ] || ok=0
		[ "$(grep "^${name} " <<<"${typst_lines}")" = "${svg_lines}" ] || ok=0
	done
	if [ "${ok}" = 1 ]; then
		report pass motif-geometry-match ""
	else
		report fail motif-geometry-match "the same shapes, points and opacities in typst/lib/motifs.typ and html/motifs/<name>.svg"
	fi
}

check_subdir_assets() {
	local dir="${work_dir}/projects/single" output ok=1 image side paper colour
	cp -R "${repo_dir}/_extensions" "${dir}/_extensions"
	if ! (cd "${dir}" && quarto render chapters/sub.qmd --to mcanouil-typst \
		--metadata-file "${tests_dir}/presets/gold.yml" >sub.out 2>sub.err); then
		ok=0
	fi
	[ -z "$(unexpected_stderr "${dir}/sub.err")" ] || ok=0
	output="$(find "${dir}" -name 'sub.pdf' | head -n 1)"
	if [ -f "${output}" ]; then
		pdffonts "${output}" | grep -q 'SourceSerif4' || ok=0
		image="$(page1_image "${output}")"
		side="$(motif_side_px "${output}")"
		paper="$(hex_rgb "$(preset_value gold light paper)")"
		colour="$(hex_rgb "$(preset_value gold light accent)")"
		shows_motif "$(motif_pixel "${image}" "${side}" 99.5 0.5)" "${paper}" "${colour}" || ok=0
	else
		ok=0
	fi
	if [ "${ok}" = 1 ]; then
		report pass subdir-assets ""
	else
		report fail subdir-assets "chapters/sub.qmd of a project to render quietly with Source Serif 4 and the motif: $(cat "${dir}/sub.err" 2>/dev/null | tail -n 3)"
	fi
}

check_typst_dark_mode() {
	local output image width height ok=1 dir="${work_dir}/typst-dark" code=0
	output="$(render typst-dark typst gold)"
	image="$(page1_image "${output}")"
	read -r width height <<<"$(ppm_size "${image}")"
	[ "$(colour_distance "$(pixel "${image}" $((width * 3 / 10)) 3)" "$(hex_rgb "$(preset_value gold dark paper)")")" -le 3 ] || ok=0
	has "${output%.pdf}.typ" 'mc-mode = "dark"' || ok=0
	cp -R "${repo_dir}/_extensions" "${dir}/_extensions"
	(cd "${dir}" && quarto render bad.qmd --to mcanouil-typst >bad.out 2>bad.err) || code=$?
	[ "${code}" != 0 ] && has "${dir}/bad.err" 'ink on paper (dark)' || ok=0
	if [ "${ok}" = 1 ]; then
		report pass typst-dark-mode ""
	else
		report fail typst-dark-mode "the gold dark paper on page 1 of a brand-mode: dark PDF, and a contrast failure on a dark pair"
	fi
}

CHECKS=(
	smoke-renders
	tool-active
	tool-optin-off
	tool-quiet
	tool-remember-optin
	preset-reaches
	preset-select-mono
	preset-default-gold
	reveal-dark-tokens
	html-dark-tokens
	user-background-dark
	link-token
	no-sass-colour-fns
	terminal-light-warns
	contrast-presets-pass
	contrast-fail-message
	partial-user-brand
	fonts-embedded
	no-hex-outside-presets
	label-en
	label-fr
	label-fallback
	label-override
	no-label-text-outside-language-files
	slots-three-only
	center-alias
	page-number-format
	report-header
	furniture-missing-metadata
	pdfua-default
	decoration-artefact
	motif-corner
	motif-geometry-match
	subdir-assets
	typst-dark-mode
)

for name in "${CHECKS[@]}"; do
	# shellcheck disable=SC2254
	case "${name}" in
	${only}) "check_${name//-/_}" ;;
	esac
done

printf '\n%s passed, %s failed\n' "${passed}" "${failed}"
[ "${failed}" -eq 0 ]
