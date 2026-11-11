#!/usr/bin/env bash
set -euo pipefail

# Render checks for the mcanouil extension.
#
# Each check is a function named check_<name> that renders fixtures and reads
# facts off the output. To add a check, define the function and list its name
# in CHECKS. Quarto does not follow symbolic links, so the extension is copied
# into a temporary work directory.
#
# Requires: quarto, and pdftotext and pdfinfo from poppler.
#
# Usage: tests/run.sh [--only <glob>]

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "${tests_dir}")"

only='*'
if [ "${1:-}" = "--only" ]; then
	only="${2:?--only needs a glob}"
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

cp -R "${repo_dir}/_extensions" "${work_dir}/_extensions"
cp -R "${tests_dir}/fixtures/." "${work_dir}/"

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
#   - "Output created: <file>".
# Anything else, a "WARN:" or "ERROR:" line or a filter message, is a problem.
# $1 stderr file.
unexpected_stderr() {
	grep -Ev $'^$|^\033\\[1m(pandoc|metadata)|^[[:space:]]|^\\[typst\\]: Compiling .*DONE$|^Output created: ' "$1" || true
}

# Render a fixture once, and answer the path of the output file. A render with
# any other stderr output counts as a failure, and stops the run.
# $1 fixture base name. $2 format, html, typst or revealjs. $3 preset base name.
render() {
	local name="$1-$2-$3" output
	output="${work_dir}/${name}.$(output_extension "$2")"
	if [ ! -f "${output}" ]; then
		if ! (cd "${work_dir}" && quarto render "$1.qmd" --to "mcanouil-$2" \
			--metadata-file "${tests_dir}/presets/$3.yml" \
			--output "${name}.$(output_extension "$2")" \
			>"${work_dir}/${name}.out" 2>"${work_dir}/${name}.err"); then
			printf 'FAIL  %s: the render failed\n' "${name}" >&2
			grep -v "^    at" "${work_dir}/${name}.err" >&2
			exit 1
		fi
		if [ -n "$(unexpected_stderr "${work_dir}/${name}.err")" ]; then
			printf 'FAIL  %s: the render wrote to stderr\n' "${name}" >&2
			unexpected_stderr "${work_dir}/${name}.err" >&2
			exit 1
		fi
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

CHECKS=(
	smoke-renders
	tool-active
	tool-optin-off
	tool-quiet
	tool-remember-optin
)

for name in "${CHECKS[@]}"; do
	# shellcheck disable=SC2254
	case "${name}" in
	${only}) "check_${name//-/_}" ;;
	esac
done

printf '\n%s passed, %s failed\n' "${passed}" "${failed}"
[ "${failed}" -eq 0 ]
