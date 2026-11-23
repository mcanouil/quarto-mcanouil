#!/usr/bin/env bash
# LOG_PREFIX and DOCS_DIR are set by the scripts that source this file.
# shellcheck disable=SC2154
#
# Documentation Project Render Helpers
# Renders a Quarto project that lives inside the website, and skips the work on
# a partial render.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# Sourced by render-demos.sh, render-samples.sh, screenshots.sh and
# sample-screenshots.sh. The caller sets LOG_PREFIX, which starts every message,
# and DOCS_DIR, the website directory.
#

# skip_partial_render <output-dir>
# A render of some files only, such as a save in `quarto preview`, keeps the
# output of the last full render: stop the script when that output exists.
skip_partial_render() {
	if [[ "${QUARTO_PROJECT_RENDER_ALL:-}" != 1 && -d "$1" ]]; then
		printf '[%s] Partial render: skip, and keep %s/\n' "${LOG_PREFIX}" "${1#"${DOCS_DIR}"/}"
		exit 0
	fi
}

# require_extension_copy <project-dir>
# The project needs its own copy of the extension, made by sync-extension.sh.
require_extension_copy() {
	if ! compgen -G "$1/_extensions/local/*/_extension.yml" >/dev/null; then
		printf '[%s] No extension copy under docs/%s/_extensions/local/; run ./docs/_scripts/sync-extension.sh first\n' \
			"${LOG_PREFIX}" "$(basename "$1")" >&2
		exit 1
	fi
}

# render_project <project-dir> <output-dir>
# Renders the project and moves its _output/ to <output-dir>, which it replaces.
render_project() {
	# The outer website render exports QUARTO_PROJECT_* variables that describe
	# its own project. Unset them, so the inner render resolves the project
	# instead. Other QUARTO_* variables, such as QUARTO_CHROMIUM, are kept.
	local name
	local env_args=()
	for name in $(compgen -e); do
		[[ "${name}" == QUARTO_PROJECT_* ]] && env_args+=(-u "${name}")
	done

	env ${env_args[@]+"${env_args[@]}"} quarto render "$1"

	rm -rf "$2"
	mv "$1/_output" "$2"
	printf '[%s] %s/_output -> %s/\n' "${LOG_PREFIX}" "$(basename "$1")" "$(basename "$2")"
}
