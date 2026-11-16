#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: cross-references in the PDF, read from the text and the link annotations.
#
# Usage: xref.sh section <text>
#
# <text> is the reference to the section sec-intro as the reader sees it,
# such as "Section Introduction" or "Section 1".
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format xref.sh
need pdftotext
need pdftohtml

# Answer the text of the PDF on one line, with each run of spaces, no-break spaces included, made one space.
flat_text() {
	pdftotext "${output}" - | sed 's/\xc2\xa0/ /g' | tr -s '[:space:]' ' '
}

# Succeed when the sentence that cites sec-intro holds the reference text.
# $1 reference text.
cites() {
	grep -qF "See $1 for the context." <<<"$(flat_text)"
}

# Answer the text under each internal link annotation of the PDF, one link a
# line. pdftohtml matches the words to the area of each annotation, so a line
# can also hold a letter or a word around the link.
link_texts() {
	pdftohtml -xml -i -stdout "${output}" | sed 's/\xc2\xa0/ /g' |
		grep -oE '<a href="[^"]*#[0-9]+">[^<]*</a>' | sed -E 's/<[^>]*>//g'
}

# Succeed when an internal link of the PDF covers the reference text.
# $1 reference text.
links() {
	link_texts | grep -qF -- "$1"
}

case "${1:-}" in
section)
	expect "section reference reads '$2'" "the text 'See $2 for the context.'" cites "$2"
	expect "section reference '$2' is a link" "an internal link over the text '$2'" links "$2"
	;;
*)
	printf 'Bail out! unknown check: %s\n' "${1:-}"
	exit 1
	;;
esac

tap_done
