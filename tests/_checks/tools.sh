#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the tool markers that a pattern cannot count, because the tool
# must run for two blocks of the document.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Succeed when a file holds a fixed string on exactly two lines.
# $1 file. $2 string.
twice() {
	[ "$(count "$1" "$2")" = 2 ]
}

# Succeed when the text of the PDF holds a fixed string on exactly two lines.
# $1 string.
pdf_twice() {
	[ "$(pdf_text "${output}" | grep -cF -- "$1" || true)" = 2 ]
}

case "${format}" in
html) expect "tool-div-reuse-active" "'<p>Reusable content.</p>' twice in the HTML" twice "${output}" '<p>Reusable content.</p>' ;;
revealjs) expect "tool-cascade-active" "'<h2>Cascade</h2>' twice in the deck" twice "${output}" '<h2>Cascade</h2>' ;;
typst)
	need pdftotext
	expect "tool-div-reuse-typst-active" "'Reusable content.' twice in the PDF" pdf_twice 'Reusable content.'
	;;
esac
tap_done
