#!/usr/bin/env bash
# BROWSER and the constants are read by the scripts that source this file.
# shellcheck disable=SC2034
#
# Documentation Screenshot Helpers
# Finds a browser and captures checked PNG screenshots for the capture scripts.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# Sourced by screenshots.sh and sample-screenshots.sh. The caller sets
# LOG_PREFIX, which starts every message of these helpers.
#

CAPTURE_TIMEOUT=60
MIN_SCREENSHOT_BYTES=10000

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
		printf '[%s] The browser stopped (status %s) or took more than %s seconds on %s\n' \
			"${LOG_PREFIX}" "${browser_status}" "${CAPTURE_TIMEOUT}" "$2" >&2
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
		printf '[%s] The screenshot of %s is missing or blank (%s bytes): %s\n' \
			"${LOG_PREFIX}" "$2" "$(png_size "$1")" "$1" >&2
		exit 1
	fi
}
