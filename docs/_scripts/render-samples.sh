#!/usr/bin/env bash
#
# Documentation Sample Render
# Renders the sample project and stages its output for the website.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# _samples/ is a Quarto project of its own: one file per variant of the
# extension (a memo kind, a report layout, the slide types), each rendered to
# the formats that its screenshots need. sample-screenshots.sh captures the
# screenshots that _samples/_screenshots.tsv lists, and the documentation pages
# show them.
#
# The output is moved to samples/, which _quarto.yml lists under
# `project.resources`, so the website publishes it as it is. samples/ is ignored
# by Git and replaced on every run.
#
# The slides sample shows the GitHub avatar of the author as the speaker photo.
# The extension reads the photo from a local file, so this script downloads it
# to _samples/speaker.png, which Git ignores.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "${SCRIPT_DIR}")"
SAMPLES_DIR="${DOCS_DIR}/_samples"
OUTPUT_DIR="${DOCS_DIR}/samples"
MANIFEST="${SAMPLES_DIR}/_screenshots.tsv"
SPEAKER_PHOTO_URL="https://github.com/mcanouil.png"
# LOG_PREFIX is read by the helpers in _render.sh.
# shellcheck disable=SC2034
LOG_PREFIX="render-samples"

# shellcheck source-path=SCRIPTDIR source=_render.sh disable=SC1091
source "${SCRIPT_DIR}/_render.sh"

skip_partial_render "${OUTPUT_DIR}"
require_extension_copy "${SAMPLES_DIR}"

# Every sample must have a screenshot, and every screenshot a sample, so that
# no sample is rendered for nothing and no screenshot points at a missing file.
sample_names="$(for source in "${SAMPLES_DIR}"/[!_]*.qmd; do basename "${source}" .qmd; done | sort)"
manifest_sources="$(grep -v '^#' "${MANIFEST}" | cut -f2 | sort -u)"
if [[ "${sample_names}" != "${manifest_sources}" ]]; then
	printf '[render-samples] The samples in docs/_samples/ and the lines of docs/_samples/_screenshots.tsv differ:\n' >&2
	diff <(printf '%s\n' "${sample_names}") <(printf '%s\n' "${manifest_sources}") |
		sed -n 's/^< /  sample without a screenshot: /p; s/^> /  screenshot of a missing sample: /p' >&2
	exit 1
fi

if ! curl -fsSL --max-time 30 "${SPEAKER_PHOTO_URL}" -o "${SAMPLES_DIR}/speaker.png"; then
	printf '[render-samples] Could not download the speaker photo from %s; check the network and render again\n' \
		"${SPEAKER_PHOTO_URL}" >&2
	exit 1
fi

render_project "${SAMPLES_DIR}" "${OUTPUT_DIR}"
