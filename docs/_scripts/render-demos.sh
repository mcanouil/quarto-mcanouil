#!/usr/bin/env bash
#
# Documentation Demo Render
# Renders the demo project and stages its output for the website.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# _demos/ is a Quarto project of its own: one file per preset, each rendered to
# mcanouil-html, mcanouil-revealjs and mcanouil-typst. A separate project keeps
# the website's sidebar, footer, brand and filters out of the demos, so each one
# is what a user of the extension gets.
#
# The output is moved to demos/, which _quarto.yml lists under
# `project.resources`, so the website publishes it as it is. demos/ is ignored by
# Git and replaced on every run.
#
# The demo project needs its own copy of the extension, made by
# sync-extension.sh, for the same reason as the website does.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "${SCRIPT_DIR}")"
DEMOS_DIR="${DOCS_DIR}/_demos"
OUTPUT_DIR="${DOCS_DIR}/demos"

# A render of some files only, such as a save in `quarto preview`, keeps the
# demos of the last full render.
if [[ "${QUARTO_PROJECT_RENDER_ALL:-}" != 1 && -d "${OUTPUT_DIR}" ]]; then
	printf '[render-demos] Partial render: skip, and keep demos/\n'
	exit 0
fi

if ! compgen -G "${DEMOS_DIR}/_extensions/local/*/_extension.yml" >/dev/null; then
	printf '[render-demos] No extension copy under docs/_demos/_extensions/local/; run ./docs/_scripts/sync-extension.sh first\n' >&2
	exit 1
fi

# demos.qmd has one tab for each demo file, written by hand, and every tab shows
# the dark HTML screenshot of its demo. Stop before the render when the demo
# files and those screenshots differ, so that no demo is published without a tab
# and no tab points at a demo that does not exist.
GALLERY="${DOCS_DIR}/demos.qmd"
demo_names="$(for source in "${DEMOS_DIR}"/[!_]*.qmd; do basename "${source}" .qmd; done | sort)"
tab_names="$(grep -o 'demos/screenshots/[A-Za-z0-9_-]*-html-dark\.png' "${GALLERY}" |
	sed 's|^demos/screenshots/||; s|-html-dark\.png$||' | sort -u)"
if [[ "${demo_names}" != "${tab_names}" ]]; then
	printf '[render-demos] The demos in docs/_demos/ and the tabs in docs/demos.qmd differ:\n' >&2
	diff <(printf '%s\n' "${demo_names}") <(printf '%s\n' "${tab_names}") |
		sed -n 's/^< /  demo without a tab: /p; s/^> /  tab without a demo: /p' >&2
	exit 1
fi

# The outer website render exports QUARTO_PROJECT_* variables that describe its
# own project. Unset them, so the inner render resolves the demo project
# instead. Other QUARTO_* variables, such as QUARTO_CHROMIUM, are kept.
env_args=()
for name in $(compgen -e); do
	[[ "${name}" == QUARTO_PROJECT_* ]] && env_args+=(-u "${name}")
done

env ${env_args[@]+"${env_args[@]}"} quarto render "${DEMOS_DIR}"

rm -rf "${OUTPUT_DIR}"
mv "${DEMOS_DIR}/_output" "${OUTPUT_DIR}"
printf '[render-demos] _demos/_output -> demos/\n'
