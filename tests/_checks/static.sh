#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: rules about the source of the extension, not about its output.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
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

# Succeed when no Typst file chooses a document type with a comparison.
type_dispatch_no_flags() {
	[ "$(grep -rc 'if type ==' "${ext_dir}/typst" | awk -F: '{ total += $NF } END { print total + 0 }')" -eq 0 ]
}

# Succeed when the schema and the manifest of the extension load with a strict
# YAML parser and hold their top-level key. The embedded tools are not checked.
manifests_strict_yaml() {
	local report status=0
	report="$(quarto pandoc lua "${tests_dir}/_checks/yaml-strict.lua" \
		"${ext_dir}/_schema.yml:options" "${ext_dir}/_extension.yml:contributes" 2>&1)" || status=$?
	printf '%s\n' "${report}" | sed -n 's/^fail /# found: /p'
	[ "${status}" -eq 0 ]
}

expect "no-sass-colour-fns" "no Sass colour function on a preset token" no_sass_colour_fns
expect "no-hex-outside-presets" "no hex colour outside presets/" no_hex_outside_presets
expect "no-label-text-outside-language-files" "no label text in lua/ or typst/" no_label_text_outside_language_files
expect "manifests-strict-yaml" "_schema.yml and _extension.yml load with a strict YAML parser" manifests_strict_yaml
expect "type-dispatch-no-flags" "no 'if type ==' in typst/" type_dispatch_no_flags
tap_done
