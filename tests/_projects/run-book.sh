#!/usr/bin/env bash
set -euo pipefail

# Render the test book to mcanouil-typst and run its PDF checks, printing TAP.
#
# The test runner cannot render a project that has its own _quarto.yml yet, so
# this script copies the book and the extension to a temporary directory,
# renders the whole book there, and runs `_checks/types.sh book` on the PDF.
#
# Usage: tests/_projects/run-book.sh
#
# Requires: quarto, veraPDF (`quarto install verapdf`), and poppler.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

projects_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
tests_dir="$(dirname "${projects_dir}")"
repo_dir="$(dirname "${tests_dir}")"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

cp -R "${projects_dir}/book/." "${work}/"
rm -rf "${work}/_book" "${work}/.quarto" "${work}/_extensions"
mkdir -p "${work}/_extensions"
cp -R "${repo_dir}/_extensions/mcanouil" "${work}/_extensions/"

if ! (cd "${work}" && quarto render --to mcanouil-typst >"${work}/render.log" 2>&1); then
	printf 'Bail out! the book did not render:\n'
	tail -n 30 "${work}/render.log"
	exit 1
fi

pdf="$(find "${work}/_book" -name '*.pdf' | head -n 1)"
if [ -z "${pdf}" ]; then
	printf 'Bail out! the book render wrote no PDF\n'
	exit 1
fi

cd "${tests_dir}"
EXTENSION_TEST_OUTPUT="${pdf}" \
	EXTENSION_TEST_INPUT="${work}/index.qmd" \
	EXTENSION_TEST_FORMAT=mcanouil-typst \
	bash _checks/types.sh book
