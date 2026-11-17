#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the title block and the author display of a Typst PDF.
#
# Usage: authors.sh
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format authors.sh
need pdftotext

# Succeed when the text of page 1 reads in content order and holds a pattern.
# $1 extended regular expression.
page1_matches() {
	pdftotext -raw -f 1 -l 1 "${output}" - | tr '\n' ' ' | grep -qE -- "$1"
}

# The PDF text may hold the diaeresis of Mickaël as a combining mark, so the name is matched loosely.
# pdftotext may also drop the narrow space between bold words, so the space in a name is optional.
# Succeed when every author name of the fixture is on page 1, with degrees in
# small type after the name, and the affiliation numbers are superscript.
authors_render() {
	local name
	for name in 'Micka.{1,4}l Canouil' 'Ana Author' 'Ben Writer' 'Cleo Reader' 'Dan Plotter' 'Eve Fitter' 'Finn Checker' 'Gus Elder'; do
		page1_matches "${name// / ?}" || return 1
	done
	page1_matches 'Micka.{1,4}l Canouil[^A-Za-z]*Ph\.D\.' &&
		page1_matches 'Ben ?Writer[[:space:]]*M\.D\., Ph\.D\.' &&
		page1_matches 'Inserm U1283' &&
		page1_matches 'Imperial College London' &&
		grep -qF 'super[' "${typ}"
}

# Succeed when each mark has its legend line, from the language file.
author_legends() {
	page1_matches 'Equal contribution' &&
		page1_matches 'Corresponding author: contact@example\.org' &&
		page1_matches 'Deceased' &&
		[ "$(pdftotext -raw -f 1 -l 1 "${output}" - | grep -c 'Equal contribution')" -eq 1 ]
}

# Succeed when both ORCID badges carry the alternative text 'ORCID <id>'.
orcid_alt() {
	local alts
	alts="$(pdf_alt_texts "${output}")"
	grep -qxF 'ORCID 0000-0002-3396-4549' <<<"${alts}" && grep -qxF 'ORCID 0000-0001-2345-6789' <<<"${alts}"
}

find_verapdf
expect "authors-render" "eight names, degrees after the name, affiliations, and superscript numbers on page 1" authors_render
expect "author-legends" "one legend line each for equal contribution, the corresponding author and deceased" author_legends
expect "orcid-alt" "the alternative texts 'ORCID 0000-0002-3396-4549' and 'ORCID 0000-0001-2345-6789' in the PDF" orcid_alt
expect "authors-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
tap_done
