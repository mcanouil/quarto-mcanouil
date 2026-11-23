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
DARK_ONLY_PRESET="terminal"
CAPTURE_TIMEOUT=60
MIN_SCREENSHOT_BYTES=10000

# A render of some files only, such as a save in `quarto preview`, keeps the
# screenshots of the last full render.
if [[ "${QUARTO_PROJECT_RENDER_ALL:-}" != 1 && -d "${OUTPUT_DIR}" ]]; then
	printf '[screenshots] Partial render: skip, and keep demos/screenshots/\n'
	exit 0
fi

BROWSER=""
checked_locations=()

# Sets BROWSER to the first executable found, and records every location
# checked, so that a failure can name them.
find_browser() {
	local name candidate
	for name in CHROME_PATH QUARTO_CHROMIUM; do
		candidate="${!name:-}"
		checked_locations+=("\$${name} (${candidate:-unset})")
		if [[ -n "${candidate}" && -x "${candidate}" ]]; then
			BROWSER="${candidate}"
			return 0
		fi
	done
	for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
		checked_locations+=("${candidate} on PATH")
		if command -v "${candidate}" >/dev/null 2>&1; then
			BROWSER="$(command -v "${candidate}")"
			return 0
		fi
	done
	for candidate in \
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		"/Applications/Chromium.app/Contents/MacOS/Chromium" \
		"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
		"/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"; do
		checked_locations+=("${candidate}")
		if [[ -x "${candidate}" ]]; then
			BROWSER="${candidate}"
			return 0
		fi
	done
	# The Chromium that Playwright downloads: the last match is the newest version.
	local pattern
	local playwright_browsers=()
	for pattern in \
		"${HOME}/Library/Caches/ms-playwright/chromium-*/chrome-mac*/*.app/Contents/MacOS/*" \
		"${HOME}/.cache/ms-playwright/chromium-*/chrome-linux*/chrome"; do
		checked_locations+=("${pattern}")
		for candidate in ${pattern}; do
			[[ -x "${candidate}" ]] && playwright_browsers+=("${candidate}")
		done
	done
	if ((${#playwright_browsers[@]} > 0)); then
		BROWSER="${playwright_browsers[${#playwright_browsers[@]} - 1]}"
		return 0
	fi
	return 1
}

# capture <browser> <url> <png> <width> <height> <scheme: light|dark>
capture() {
	local scheme_value=1
	[[ "$6" == dark ]] && scheme_value=0
	"$1" --headless=new --disable-gpu --hide-scrollbars \
		--blink-settings="preferredColorScheme=${scheme_value}" \
		--window-size="$4,$5" --virtual-time-budget=5000 \
		--screenshot="$3" "$2" >/dev/null 2>&1 &
	local browser_pid=$!
	# A headless browser can hang without writing anything. Stop it after
	# CAPTURE_TIMEOUT seconds, so the render fails instead of waiting forever.
	# The watchdog drops its output: Quarto waits until every process that holds
	# the script's output has closed it, and an orphaned sleep would hold it for
	# CAPTURE_TIMEOUT seconds after the script ends.
	(sleep "${CAPTURE_TIMEOUT}" && kill "${browser_pid}") </dev/null >/dev/null 2>&1 &
	local watchdog_pid=$!
	local browser_status=0
	wait "${browser_pid}" || browser_status=$?
	kill "${watchdog_pid}" 2>/dev/null || true
	# Chromium can exit with an error on teardown after it wrote a good
	# screenshot, so the error counts only when the screenshot is not usable.
	if ((browser_status != 0)) && ! png_is_usable "$3"; then
		printf '[screenshots] The browser stopped (status %s) or took more than %s seconds on %s\n' \
			"${browser_status}" "${CAPTURE_TIMEOUT}" "$2" >&2
		exit 1
	fi
	check_png "$3" "$2"
}

# png_size <png>: the size in bytes, or 0 when the file does not exist.
png_size() {
	if [[ -f "$1" ]]; then
		wc -c <"$1" | tr -d ' '
	else
		printf '0\n'
	fi
}

# png_is_usable <png>
# A blank page gives a PNG of a few kilobytes; a real screenshot is larger than
# MIN_SCREENSHOT_BYTES.
png_is_usable() {
	(($(png_size "$1") >= MIN_SCREENSHOT_BYTES))
}

# check_png <png> <source>
check_png() {
	if ! png_is_usable "$1"; then
		printf '[screenshots] The screenshot of %s is missing or blank (%s bytes): %s\n' \
			"$2" "$(png_size "$1")" "$1" >&2
		exit 1
	fi
}

if ! find_browser; then
	printf '[screenshots] No Chromium-based browser found. Checked:\n' >&2
	printf '  - %s\n' "${checked_locations[@]}" >&2
	printf 'Set CHROME_PATH to the browser executable and render again.\n' >&2
	exit 1
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# The fonts of the extension copy that sync-extension.sh makes.
font_dirs=("${DEMOS_SOURCE_DIR}"/_extensions/local/*/fonts)
if [[ ! -d "${font_dirs[0]}" ]]; then
	printf '[screenshots] No fonts under docs/_demos/_extensions/local/; run ./docs/_scripts/sync-extension.sh first\n' >&2
	exit 1
fi

# One demo per <preset>.qmd; _body.qmd and other partials start with `_`.
for source in "${DEMOS_SOURCE_DIR}"/[!_]*.qmd; do
	preset="$(basename "${source}" .qmd)"
	html_url="file://${DEMOS_DIR}/${preset}.html"
	slides_url="file://${DEMOS_DIR}/${preset}-revealjs.html"
	if [[ "${preset}" != "${DARK_ONLY_PRESET}" ]]; then
		capture "${BROWSER}" "${html_url}" "${OUTPUT_DIR}/${preset}-html-light.png" 1280 800 light
	fi
	capture "${BROWSER}" "${html_url}" "${OUTPUT_DIR}/${preset}-html-dark.png" 1280 800 dark
	capture "${BROWSER}" "${slides_url}#/0" "${OUTPUT_DIR}/${preset}-revealjs-1.png" 1280 720 light
	# Each `#` section is a vertical stack, so `#/1/1` is the first slide after
	# the first section title.
	capture "${BROWSER}" "${slides_url}#/1/1" "${OUTPUT_DIR}/${preset}-revealjs-3.png" 1280 720 light
	(
		cd "${DEMOS_SOURCE_DIR}"
		quarto typst compile --format png --ppi 110 --pages 1-2 \
			--font-path "${font_dirs[0]}" \
			"${preset}.typ" "${OUTPUT_DIR}/${preset}-typst-{p}.png"
	)
	check_png "${OUTPUT_DIR}/${preset}-typst-1.png" "${preset}.typ page 1"
	check_png "${OUTPUT_DIR}/${preset}-typst-2.png" "${preset}.typ page 2"
done

printf '[screenshots] %s -> demos/screenshots/\n' "$(basename "${BROWSER}")"
