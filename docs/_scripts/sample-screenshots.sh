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

# A render of some files only, such as a save in `quarto preview`, keeps the
# screenshots of the last full render.
if [[ "${QUARTO_PROJECT_RENDER_ALL:-}" != 1 && -d "${OUTPUT_DIR}" ]]; then
	printf '[%s] Partial render: skip, and keep samples/screenshots/\n' "${LOG_PREFIX}"
	exit 0
fi

# Every reference on a page must name a screenshot of the list, and every
# screenshot of the list must be shown on a page.
manifest_names="$(grep -v '^#' "${MANIFEST}" | cut -f1 | sort -u)"
references="$(
	cd "${DOCS_DIR}"
	# grep finds no reference before the pages show any, which is not an error.
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
if ((reference_errors)); then
	printf '[%s] Fix the pages or docs/_samples/_screenshots.tsv and render again\n' "${LOG_PREFIX}" >&2
	exit 1
fi

if ! find_browser; then
	printf '[%s] No Chromium-based browser found. Checked:\n' "${LOG_PREFIX}" >&2
	# checked_locations is set by find_browser in _capture.sh.
	# shellcheck disable=SC2154
	printf '  - %s\n' "${checked_locations[@]}" >&2
	printf 'Set CHROME_PATH to the browser executable and render again.\n' >&2
	exit 1
fi

# The fonts of the extension copy that sync-extension.sh makes.
font_dirs=("${SAMPLES_SOURCE_DIR}"/_extensions/local/*/fonts)
if [[ ! -d "${font_dirs[0]}" ]]; then
	printf '[%s] No fonts under docs/_samples/_extensions/local/; run ./docs/_scripts/sync-extension.sh first\n' "${LOG_PREFIX}" >&2
	exit 1
fi

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
	html)
		capture "${BROWSER}" "file://${SAMPLES_DIR}/${source}.html" "${png}" 1280 800 light
		;;
	revealjs)
		capture "${BROWSER}" "file://${SAMPLES_DIR}/${source}-revealjs.html${target}" "${png}" 1280 720 light
		;;
	typst)
		(
			cd "${SAMPLES_SOURCE_DIR}"
			quarto typst compile --format png --ppi 110 --pages "${target}" \
				--font-path "${font_dirs[0]}" "${source}.typ" "${png}"
		)
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
