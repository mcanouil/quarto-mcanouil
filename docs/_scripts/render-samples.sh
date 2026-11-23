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

# A render of some files only, such as a save in `quarto preview`, keeps the
# samples of the last full render.
if [[ "${QUARTO_PROJECT_RENDER_ALL:-}" != 1 && -d "${OUTPUT_DIR}" ]]; then
	printf '[render-samples] Partial render: skip, and keep samples/\n'
	exit 0
fi

if ! compgen -G "${SAMPLES_DIR}/_extensions/local/*/_extension.yml" >/dev/null; then
	printf '[render-samples] No extension copy under docs/_samples/_extensions/local/; run ./docs/_scripts/sync-extension.sh first\n' >&2
	exit 1
fi

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

# The outer website render exports QUARTO_PROJECT_* variables that describe its
# own project. Unset them, so the inner render resolves the sample project
# instead. Other QUARTO_* variables, such as QUARTO_CHROMIUM, are kept.
env_args=()
for name in $(compgen -e); do
	[[ "${name}" == QUARTO_PROJECT_* ]] && env_args+=(-u "${name}")
done

env ${env_args[@]+"${env_args[@]}"} quarto render "${SAMPLES_DIR}"

rm -rf "${OUTPUT_DIR}"
mv "${SAMPLES_DIR}/_output" "${OUTPUT_DIR}"
printf '[render-samples] _samples/_output -> samples/\n'
