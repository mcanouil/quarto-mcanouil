#!/usr/bin/env bash
set -euo pipefail

# Accessibility checks of rendered output.
#
# pdf: validates a PDF against the PDF/UA-1 profile of veraPDF, run from the
# verapdf/cli Docker image. The image entry point is the veraPDF command line
# and its working directory is /data, so the directory of the file is mounted
# there. The directory path is resolved with symbolic links followed, because
# Docker Desktop on macOS shares /private/var, not /var.
#
# Requires: docker.
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

# Validate a PDF with the veraPDF PDF/UA-1 profile. Print the summary line and
# each failed rule, and fail when the file is not compliant.
# $1 PDF file.
check_pdf() {
	local file="$1" dir name report
	if [ ! -f "${file}" ]; then
		printf 'a11y: no PDF file at %s\n' "${file}" >&2
		exit 2
	fi
	if ! command -v docker >/dev/null 2>&1; then
		printf 'a11y: docker is not installed; it runs the verapdf/cli image.\n' >&2
		exit 2
	fi
	dir="$(cd "$(dirname "${file}")" && pwd -P)"
	name="$(basename "${file}")"
	report="$(docker run --rm -v "${dir}:/data" verapdf/cli --flavour ua1 "/data/${name}")"
	if ! grep -q '<validationReport ' <<<"${report}"; then
		printf 'a11y: veraPDF wrote no validation report for %s:\n%s\n' "${file}" "${report}" >&2
		exit 2
	fi
	grep -oE '<details [^>]*>' <<<"${report}"
	if grep -q 'isCompliant="true"' <<<"${report}"; then
		printf 'pass  pdf-ua1 %s\n' "${name}"
		return 0
	fi
	grep -oE '<rule [^>]*status="failed"[^>]*>' <<<"${report}" || true
	printf 'FAIL  pdf-ua1 %s\n' "${name}"
	return 1
}

case "${1:-}" in
pdf)
	[ $# -eq 2 ] || usage
	check_pdf "$2"
	;;
*) usage ;;
esac
