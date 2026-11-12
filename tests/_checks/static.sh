#!/usr/bin/env bash
set -euo pipefail

# Check hook: rules about the source of the extension, not about its output.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Succeed when no Sass colour function takes a preset token.
no_sass_colour_fns() {
	local found
	# shellcheck disable=SC2016 # the $ in the pattern is a literal Sass variable prefix
	found="$(grep -rEn '(^|[^-[:alnum:]])(mix|lighten|darken|shade-color|tint-color)\([^;]*(\$mc-|var\(--mc-)' \
		"${ext_dir}/html" "${ext_dir}/revealjs" || true)"
	[ -z "${found}" ] || printf '# found: %s\n' "${found}"
	[ -z "${found}" ]
}

# Succeed when no hex colour sits outside the presets.
no_hex_outside_presets() {
	local dir found=""
	for dir in lua typst html revealjs; do
		found+="$(grep -rEn '#[0-9a-fA-F]{3,8}\b' "${ext_dir}/${dir}" || true)"
	done
	[ -z "${found}" ] || printf '# found: %s\n' "${found}"
	[ -z "${found}" ]
}

# Succeed when no label text sits outside the language files.
no_label_text_outside_language_files() {
	local found
	found="$(grep -rEn 'In this chapter|Dans ce chapitre|Invoice number|Postscript' \
		"${ext_dir}/lua" "${ext_dir}/typst" || true)"
	[ -z "${found}" ] || printf '# found: %s\n' "${found}"
	[ -z "${found}" ]
}

expect "no-sass-colour-fns" "no Sass colour function on a preset token" no_sass_colour_fns
expect "no-hex-outside-presets" "no hex colour outside presets/" no_hex_outside_presets
expect "no-label-text-outside-language-files" "no label text in lua/ or typst/" no_label_text_outside_language_files
tap_done
