#!/usr/bin/env bash
set -euo pipefail

# Accessibility checks of rendered output.
#
# pdf: validates a PDF against the PDF/UA-1 profile with the veraPDF command
# line that `quarto install verapdf` puts in the Quarto data directory, the
# same validator Quarto runs during a render. VERAPDF overrides the path.
#
# Requires: quarto install verapdf (and Java).
#
# Usage: tests/a11y/run.sh pdf <file.pdf>
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

usage() {
	printf 'usage: %s pdf <file.pdf>\n' "$0" >&2
	exit 2
}

# Answer the path of the veraPDF command line: VERAPDF, then the copy that
# Quarto installs on macOS and on Linux.
verapdf_command() {
	local candidate
	for candidate in "${VERAPDF:-}" \
		"${HOME}/Library/Application Support/quarto/verapdf/verapdf" \
		"${XDG_DATA_HOME:-${HOME}/.local/share}/quarto/verapdf/verapdf"; do
		if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
			printf '%s' "${candidate}"
			return 0
		fi
	done
	printf 'a11y: veraPDF is not installed; run "quarto install verapdf", or set VERAPDF to its command line.\n' >&2
	exit 2
}

# Validate a PDF with the veraPDF PDF/UA-1 profile. Print the summary line and
# each failed rule, and fail when the file is not compliant.
# $1 PDF file.
check_pdf() {
	local file="$1" verapdf report
	if [ ! -f "${file}" ]; then
		printf 'a11y: no PDF file at %s\n' "${file}" >&2
		exit 2
	fi
	verapdf="$(verapdf_command)"
	report="$("${verapdf}" --flavour ua1 "${file}")"
	if ! grep -q '<validationReport ' <<<"${report}"; then
		printf 'a11y: veraPDF wrote no validation report for %s:\n%s\n' "${file}" "${report}" >&2
		exit 2
	fi
	grep -oE '<details [^>]*>' <<<"${report}"
	if grep -q 'isCompliant="true"' <<<"${report}"; then
		printf 'pass  pdf-ua1 %s\n' "$(basename "${file}")"
		return 0
	fi
	grep -oE '<rule [^>]*status="failed"[^>]*>' <<<"${report}" || true
	printf 'FAIL  pdf-ua1 %s\n' "$(basename "${file}")"
	return 1
}

case "${1:-}" in
pdf)
	[ $# -eq 2 ] || usage
	check_pdf "$2"
	;;
*) usage ;;
esac
