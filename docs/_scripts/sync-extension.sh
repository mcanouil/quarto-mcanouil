#!/usr/bin/env bash
#
# Documentation Extension Sync
# Mirrors the repository's own extension into the documentation project.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# The website demonstrates the extension it documents, so the extension has to
# be resolvable from docs/. Quarto builds its extension registry while reading
# _quarto.yml, before any pre-render script runs and without following symlinks,
# so a staged or linked copy is not found: shortcodes report "not found" and the
# page renders empty. The copy therefore has to exist on disk before Quarto
# starts.
#
# The repository root stays the single source of truth, so the copy is ignored
# by Git rather than committed. Run this script before previewing locally; the
# Pages workflow runs it before every render.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "${SCRIPT_DIR}")"
ROOT_DIR="$(dirname "${DOCS_DIR}")"
# Under a `local` owner directory: the copy is generated from this repository
# rather than installed from anywhere, and saying so in the path keeps it
# distinct from the vendored dependencies. It also avoids a collision when the
# extension is named after its owner.
#
# The demo project under _demos/ is a separate Quarto project, so it gets its
# own copy for the same reason.
TARGET_DIRS=("${DOCS_DIR}/_extensions/local" "${DOCS_DIR}/_demos/_extensions/local" "${DOCS_DIR}/_samples/_extensions/local")

for extension_dir in "${ROOT_DIR}"/_extensions/*/; do
	[[ -f "${extension_dir}_extension.yml" ]] || continue
	extension_name="$(basename "${extension_dir}")"
	for target_dir in "${TARGET_DIRS[@]}"; do
		target="${target_dir}/${extension_name}"
		# Remove first: copying onto an existing directory nests the new copy
		# inside the old one.
		rm -rf "${target}"
		mkdir -p "${target_dir}"
		cp -R "${extension_dir%/}" "${target}"
		printf '[sync] _extensions/%s -> %s\n' \
			"${extension_name}" "${target#"${ROOT_DIR}"/}"
	done
done
