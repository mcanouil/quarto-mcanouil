#!/usr/bin/env bash
#
# Documentation Sample Screenshots
# Captures the PNG screenshots of the rendered samples for the documentation pages.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# Runs after render-samples.sh, and writes to samples/screenshots/, which is
# ignored by Git and published with the samples. _samples/_screenshots.tsv lists
# one screenshot per line, tab separated:
#
#   name     PNG file name without extension
#   source   base name of the sample
#   kind     html, revealjs or typst
#   target   - for html, the slide anchor for revealjs, the page for typst
#
# The pages show each screenshot as samples/screenshots/<name>.png. Before the
# capture, the script stops when a page refers to a name that the list does not
# have, or when the list has a name that no page refers to.
#
# HTML and Reveal.js are captured in the light scheme with the browser that
# _capture.sh finds. The PDF pages come from the Typst source that the sample
# render keeps, through the Typst bundled with Quarto.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "${SCRIPT_DIR}")"
SAMPLES_SOURCE_DIR="${DOCS_DIR}/_samples"
SAMPLES_DIR="${DOCS_DIR}/samples"
MANIFEST="${SAMPLES_SOURCE_DIR}/_screenshots.tsv"
OUTPUT_DIR="${SAMPLES_DIR}/screenshots"
STAGING_DIR="${SAMPLES_DIR}/.screenshots-staging"
LOG_PREFIX="sample-screenshots"

# shellcheck source-path=SCRIPTDIR source=_capture.sh disable=SC1091
source "${SCRIPT_DIR}/_capture.sh"
# shellcheck source-path=SCRIPTDIR source=_render.sh disable=SC1091
source "${SCRIPT_DIR}/_render.sh"

skip_partial_render "${OUTPUT_DIR}"

# Every reference on a page must name a screenshot of the list, and every
# screenshot of the list must be shown on a page.
manifest_names="$(grep -v '^#' "${MANIFEST}" | cut -f1 | sort -u)"
duplicate_names="$(grep -v '^#' "${MANIFEST}" | cut -f1 | sort | uniq -d)"
if [[ -n "${duplicate_names}" ]]; then
	printf '[%s] Each screenshot name must be unique in docs/_samples/_screenshots.tsv; repeated: %s\n' \
		"${LOG_PREFIX}" "$(paste -sd ' ' - <<<"${duplicate_names}")" >&2
	exit 1
fi
references="$(
	cd "${DOCS_DIR}" || exit 1
	# grep exits 1 when no page refers to a screenshot. The check below then
	# reports each screenshot as used by no page.
	{ grep -rHo --include='*.qmd' --exclude-dir='_samples' --exclude-dir='_demos' \
		'samples/screenshots/[A-Za-z0-9_-]*\.png' . || true; } |
		sed 's|^\./||; s|samples/screenshots/||; s|\.png$||' | sort -u
)"
referenced_names="$(cut -d: -f2 <<<"${references}" | sort -u)"
reference_errors=0
while IFS=: read -r page name; do
	[[ -z "${name}" ]] && continue
	if ! grep -qxF "${name}" <<<"${manifest_names}"; then
		printf '[%s] %s: no screenshot named %s\n' "${LOG_PREFIX}" "${page}" "${name}" >&2
		reference_errors=1
	fi
done <<<"${references}"
while read -r name; do
	if ! grep -qxF "${name}" <<<"${referenced_names}"; then
		printf '[%s] screenshot %s is used by no page\n' "${LOG_PREFIX}" "${name}" >&2
		reference_errors=1
	fi
done <<<"${manifest_names}"
# The pages also link each full render. Every linked file must exist in samples/.
while IFS=: read -r page target; do
	[[ -z "${target}" ]] && continue
	if [[ ! -f "${SAMPLES_DIR}/${target}" ]]; then
		printf '[%s] %s: the link to samples/%s points at no rendered file\n' "${LOG_PREFIX}" "${page}" "${target}" >&2
		reference_errors=1
	fi
done < <(
	cd "${DOCS_DIR}" || exit 1
	# grep exits 1 when no page links a render.
	{ grep -rHoE --include='*.qmd' --exclude-dir='_samples' --exclude-dir='_demos' \
		'\.\./samples/[A-Za-z0-9_-]+\.(pdf|html)' . || true; } |
		sed 's|^\./||; s|\.\./samples/||' | sort -u
)
if ((reference_errors)); then
	printf '[%s] Fix the pages or docs/_samples/_screenshots.tsv and render again\n' "${LOG_PREFIX}" >&2
	exit 1
fi

require_browser
require_fonts "${SAMPLES_SOURCE_DIR}"

# Capture into a staging directory and move it into place at the end, so that
# samples/screenshots/ exists only after a complete run. The partial-render
# guard above trusts that directory, so a failed run must not leave a partial
# one.
rm -rf "${OUTPUT_DIR}" "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
trap 'rm -rf "${STAGING_DIR}"' EXIT

while IFS=$'\t' read -r name source kind target; do
	[[ -z "${name}" || "${name}" == \#* ]] && continue
	png="${STAGING_DIR}/${name}.png"
	case "${kind}" in
	html) rendered="${SAMPLES_DIR}/${source}.html" ;;
	revealjs) rendered="${SAMPLES_DIR}/${source}-revealjs.html" ;;
	typst) rendered="${SAMPLES_SOURCE_DIR}/${source}.typ" ;;
	*) rendered="" ;;
	esac
	if [[ -n "${rendered}" && ! -f "${rendered}" ]]; then
		printf '[%s] %s: the render of %s has no %s file (%s); add the format to docs/_samples/%s.qmd or correct docs/_samples/_screenshots.tsv\n' \
			"${LOG_PREFIX}" "${name}" "${source}" "${kind}" "${rendered#"${DOCS_DIR}"/}" "${source}" >&2
		exit 1
	fi
	case "${kind}" in
	html)
		capture "${BROWSER}" "file://${SAMPLES_DIR}/${source}.html" "${png}" 1280 800 light
		;;
	revealjs)
		# Reveal.js shows the first slide for an anchor that matches no slide, so
		# a renamed heading would give the title slide with no error.
		deck="${SAMPLES_DIR}/${source}-revealjs.html"
		if ! grep -qF "id=\"${target#\#/}\"" "${deck}"; then
			printf '[%s] %s: no slide with the id %s in samples/%s-revealjs.html; correct docs/_samples/_screenshots.tsv\n' \
				"${LOG_PREFIX}" "${name}" "${target#\#/}" "${source}" >&2
			exit 1
		fi
		capture "${BROWSER}" "file://${deck}${target}" "${png}" 1280 720 light
		;;
	typst)
		capture_typst "${SAMPLES_SOURCE_DIR}" "${source}.typ" "${target}" "${png}"
		check_png "${png}" "${source}.typ page ${target}"
		;;
	*)
		printf '[%s] Unknown kind "%s" for %s in docs/_samples/_screenshots.tsv; use html, revealjs or typst\n' \
			"${LOG_PREFIX}" "${kind}" "${name}" >&2
		exit 1
		;;
	esac
done <"${MANIFEST}"

mv "${STAGING_DIR}" "${OUTPUT_DIR}"
printf '[%s] %s -> samples/screenshots/\n' "${LOG_PREFIX}" "$(basename "${BROWSER}")"
