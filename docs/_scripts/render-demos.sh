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
# LOG_PREFIX is read by the helpers in _render.sh.
# shellcheck disable=SC2034
LOG_PREFIX="render-demos"

# shellcheck source-path=SCRIPTDIR source=_render.sh disable=SC1091
source "${SCRIPT_DIR}/_render.sh"

skip_partial_render "${OUTPUT_DIR}"
require_extension_copy "${DEMOS_DIR}"

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

render_project "${DEMOS_DIR}" "${OUTPUT_DIR}"
