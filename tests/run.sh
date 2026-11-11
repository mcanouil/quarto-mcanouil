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
cp "${tests_dir}"/fixtures/*.qmd "${work_dir}/"

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

# Render a fixture once, and answer the path of the output file. A render with
# any stderr output counts as a failure, and stops the run.
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
		if [ -s "${work_dir}/${name}.err" ] && grep -qi 'warn' "${work_dir}/${name}.err"; then
			printf 'FAIL  %s: the render warned\n' "${name}" >&2
			cat "${work_dir}/${name}.err" >&2
			exit 1
		fi
	fi
	printf '%s' "${output}"
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

check_smoke_renders() {
	local pdf html slides
	pdf="$(render smoke typst gold)"
	html="$(render smoke html gold)"
	slides="$(render smoke revealjs gold)"
	if [ "$(pdf_page_count "${pdf}")" = "1" ] && has "${html}" '<main' && [ -s "${slides}" ]; then
		report pass smoke-renders ""
	else
		report fail smoke-renders "one PDF page, <main in the HTML, and a revealjs file"
	fi
}

CHECKS=(
	smoke-renders
)

for name in "${CHECKS[@]}"; do
	# shellcheck disable=SC2254
	case "${name}" in
	${only}) "check_${name//-/_}" ;;
	esac
done

printf '\n%s passed, %s failed\n' "${passed}" "${failed}"
[ "${failed}" -eq 0 ]
