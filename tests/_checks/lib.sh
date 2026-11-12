# shellcheck shell=bash
# Shared functions of the check hooks.
#
# A check hook is a script that quarto-extension-test runs after the assertions
# of a document pass. It reads the render from the EXTENSION_TEST_* variables,
# prints one TAP line for each check on standard output, and exits non-zero when
# a check failed. The working directory is the tests directory.
#
# Requires: pdftotext, pdfinfo, pdffonts and pdftoppm from poppler for the PDF
# checks, and `quarto install verapdf` for the tag tree checks.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
repo_dir="$(dirname "${tests_dir}")"
ext_dir="${repo_dir}/_extensions/mcanouil"

# The format name without the extension prefix: html, revealjs or typst.
format="${EXTENSION_TEST_FORMAT##*-}"
output="${EXTENSION_TEST_OUTPUT:-}"
# The Typst source that a keep-typ render leaves beside the input, or beside
# the index.qmd of a project case, whose input is the project directory.
typ="${EXTENSION_TEST_INPUT:-}"
if [ -d "${typ}" ]; then
	typ="${typ}/index.typ"
else
	typ="${typ%.qmd}.typ"
fi

tap_n=0
tap_failed=0

# Report a passing check.
# $1 name.
tap_ok() {
	tap_n=$((tap_n + 1))
	printf 'ok %d - %s\n' "${tap_n}" "$1"
}

# Report a failing check, and what it expected.
# $1 name. $2 what the check expected.
tap_not_ok() {
	tap_n=$((tap_n + 1))
	tap_failed=$((tap_failed + 1))
	printf 'not ok %d - %s\n' "${tap_n}" "$1"
	printf '# expected %s\n' "$2"
}

# Run a command, and report its outcome as one check.
# $1 name. $2 what the check expects. The rest is the command.
expect() {
	local name="$1" what="$2"
	shift 2
	if "$@"; then
		tap_ok "${name}"
	else
		tap_not_ok "${name}" "${what}"
	fi
}

# Print the plan, and answer whether every check passed.
tap_done() {
	printf '1..%d\n' "${tap_n}"
	[ "${tap_failed}" -eq 0 ]
}

# Stop with the skip code, for a format that the hook does not check.
skip_format() {
	printf '# %s does not apply to the %s format\n' "$1" "${format}"
	exit 77
}

# Stop when a tool is missing: a hook that cannot run must not pass.
# $1 command name.
need() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'Bail out! %s is not installed\n' "$1"
		exit 1
	fi
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

# Answer the value of a token in a preset file of the extension.
# $1 preset name. $2 scheme, light or dark. $3 token.
preset_value() {
	awk -v mode="$2:" -v token="  $3:" '
		/^[^ #]/ { in_mode = ($1 == mode) }
		in_mode && index($0, token) == 1 { gsub(/[" ]/, "", $2); print $2; exit }
	' "${ext_dir}/presets/$1.yml"
}

# Answer the one-line CSS rule of a selector in an HTML file.
# $1 file. $2 selector, as written before the opening brace.
css_rule() {
	grep -F -- "$2 {" "$1" | head -n 1
}

# Succeed when a Typst source holds a token with a colour.
# $1 token. $2 hex colour.
typ_token() {
	has "${typ}" "$1: rgb(\"$2\")"
}

# Succeed when a CSS rule of the output holds a token with a colour.
# $1 selector. $2 token. $3 hex colour.
css_token() {
	css_rule "${output}" "$1" | grep -qF -- "--mc-$2: $3;"
}

# Succeed when the light rules of an HTML document, the :root rule of a
# Reveal.js deck, or the token dictionary of a Typst file hold a token with
# a colour.
# $1 token. $2 hex colour.
reaches() {
	case "${format}" in
	html) css_token 'body.quarto-light' "$1" "$2" ;;
	revealjs) css_token ':root' "$1" "$2" ;;
	typst) typ_token "$1" "$2" ;;
	esac
}

# Render page 1 of the PDF to a PPM image at 50 dpi, again when the PDF is newer, and answer its path.
page1_image() {
	local image="${output%.pdf}-page1"
	if [ ! -f "${image}.ppm" ] || [ "${output}" -nt "${image}.ppm" ]; then
		pdftoppm -r 50 -f 1 -l 1 -singlefile "${output}" "${image}"
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

# Answer the side of the page 1 motif, in pixels at 50 dpi, from the motif size
# that the kept Typst file uses.
motif_side_px() {
	local points
	points="$(typst_value "${typ}" mc-first-page-motif-size 'mc-first-page-motif-size.pt()' || printf 0)"
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

# Set verapdf_bin to the veraPDF command line: VERAPDF, then the copy that
# Quarto installs on macOS and on Linux. A hook that cannot find it stops.
find_verapdf() {
	local candidate
	for candidate in "${VERAPDF:-}" \
		"${HOME}/Library/Application Support/quarto/verapdf/verapdf" \
		"${XDG_DATA_HOME:-${HOME}/.local/share}/quarto/verapdf/verapdf"; do
		if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
			verapdf_bin="${candidate}"
			return 0
		fi
	done
	printf 'Bail out! veraPDF is not installed; run "quarto install verapdf", or set VERAPDF to its command line.\n'
	exit 1
}

# Succeed when the PDF complies with the PDF/UA-1 profile of veraPDF.
# Needs find_verapdf first.
# $1 PDF file.
verapdf_ua1() {
	local report
	report="$("${verapdf_bin}" --flavour ua1 "$1")"
	grep -q '<validationReport ' <<<"${report}" && grep -q 'isCompliant="true"' <<<"${report}"
}

# Answer the alternative texts of a PDF, one per line, from the /Alt entries of
# its objects (inflating the compressed streams that hold them).
# $1 PDF file.
pdf_alt_texts() {
	python3 -I - "$1" <<'PY'
import re
import sys
import zlib

data = open(sys.argv[1], "rb").read()
chunks = [data]
for match in re.finditer(rb"stream\r?\n", data):
    end = data.find(b"endstream", match.end())
    try:
        chunks.append(zlib.decompress(data[match.end():end]))
    except zlib.error:
        continue
for chunk in chunks:
    for literal in re.findall(rb"/Alt\s*\(((?:[^()\\]|\\.)*)\)", chunk):
        print(literal.decode("latin-1"))
    for hexed in re.findall(rb"/Alt\s*<([0-9A-Fa-f\s]*)>", chunk):
        raw = bytes.fromhex(re.sub(rb"\s", b"", hexed).decode())
        print(raw.decode("utf-16-be") if raw[:2] == b"\xfe\xff" else raw.decode("latin-1"))
PY
}
