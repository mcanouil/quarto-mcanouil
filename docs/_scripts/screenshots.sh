#!/usr/bin/env bash
#
# Documentation Demo Screenshots
# Captures PNG screenshots of the rendered demos for the gallery page.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# Runs after render-demos.sh, and writes to demos/screenshots/, which is ignored
# by Git and published with the demos. demos.qmd uses these file names:
#
#   <preset>-html-light.png    HTML page, light scheme (not for terminal)
#   <preset>-html-dark.png     HTML page, dark scheme
#   <preset>-revealjs-1.png    Reveal.js title slide
#   <preset>-revealjs-3.png    Reveal.js third slide, the first content slide
#   <preset>-typst-1.png       PDF page 1
#   <preset>-typst-2.png       PDF page 2
#
# HTML and Reveal.js are captured with a headless Chromium-based browser. The
# colour scheme is always set explicitly: without the flag, the page follows the
# theme of the operating system. The PDF pages come from the Typst source that
# the demo render keeps, through the Typst bundled with Quarto, so they need no
# browser.
#
# The browser is the first one found in: $CHROME_PATH, $QUARTO_CHROMIUM, a
# Chrome or Chromium command on PATH, then the Chrome, Chromium, Brave and Edge
# applications on macOS, then the Chromium that Playwright downloads.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "${SCRIPT_DIR}")"
DEMOS_SOURCE_DIR="${DOCS_DIR}/_demos"
DEMOS_DIR="${DOCS_DIR}/demos"
OUTPUT_DIR="${DEMOS_DIR}/screenshots"
STAGING_DIR="${DEMOS_DIR}/.screenshots-staging"
DARK_ONLY_PRESET="terminal"
# LOG_PREFIX is read by the helpers in _capture.sh.
# shellcheck disable=SC2034
LOG_PREFIX="screenshots"

# shellcheck source-path=SCRIPTDIR source=_capture.sh disable=SC1091
source "${SCRIPT_DIR}/_capture.sh"
# shellcheck source-path=SCRIPTDIR source=_render.sh disable=SC1091
source "${SCRIPT_DIR}/_render.sh"

skip_partial_render "${OUTPUT_DIR}"

require_browser
require_fonts "${DEMOS_SOURCE_DIR}"

# Capture into a staging directory and move it into place at the end, so that
# demos/screenshots/ exists only after a complete run. The partial-render guard
# above trusts that directory, so a failed run must not leave a partial one.
rm -rf "${OUTPUT_DIR}" "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
trap 'rm -rf "${STAGING_DIR}"' EXIT

# One demo per <preset>.qmd; _body.qmd and other partials start with `_`.
for source in "${DEMOS_SOURCE_DIR}"/[!_]*.qmd; do
	preset="$(basename "${source}" .qmd)"
	html_url="file://${DEMOS_DIR}/${preset}.html"
	slides_url="file://${DEMOS_DIR}/${preset}-revealjs.html"
	if [[ "${preset}" != "${DARK_ONLY_PRESET}" ]]; then
		capture "${BROWSER}" "${html_url}" "${STAGING_DIR}/${preset}-html-light.png" 1280 800 light
	fi
	capture "${BROWSER}" "${html_url}" "${STAGING_DIR}/${preset}-html-dark.png" 1280 800 dark
	capture "${BROWSER}" "${slides_url}#/0" "${STAGING_DIR}/${preset}-revealjs-1.png" 1280 720 light
	# Each `#` section is a vertical stack, so `#/1/1` is the first slide after
	# the first section title.
	capture "${BROWSER}" "${slides_url}#/1/1" "${STAGING_DIR}/${preset}-revealjs-3.png" 1280 720 light
	capture_typst "${DEMOS_SOURCE_DIR}" "${preset}.typ" 1-2 "${STAGING_DIR}/${preset}-typst-{p}.png"
	check_png "${STAGING_DIR}/${preset}-typst-1.png" "${preset}.typ page 1"
	check_png "${STAGING_DIR}/${preset}-typst-2.png" "${preset}.typ page 2"
done

mv "${STAGING_DIR}" "${OUTPUT_DIR}"
printf '[screenshots] %s -> demos/screenshots/\n' "$(basename "${BROWSER}")"
