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
# The output is copied to demos/, which _quarto.yml lists under
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

if ! compgen -G "${DEMOS_DIR}/_extensions/local/*/_extension.yml" >/dev/null; then
	printf '[render-demos] No extension copy under docs/_demos/_extensions/local/; run ./docs/_scripts/sync-extension.sh first\n' >&2
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
cp -R "${DEMOS_DIR}/_output" "${OUTPUT_DIR}"
printf '[render-demos] _demos/_output -> demos/\n'
