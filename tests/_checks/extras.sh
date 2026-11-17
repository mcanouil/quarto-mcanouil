#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the features of the embedded typst-extras tool, through the mcanouil format.
#
# Usage: extras.sh list-of
#        extras.sh watermark
#        extras.sh sections
#        extras.sh chapters
#        extras.sh chapters-unnumbered
#        extras.sh sections-unnumbered
#        extras.sh book
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format extras.sh
need pdftotext
find_verapdf

# Succeed when the text of the PDF holds a fixed string.
# $1 string.
pdf_has() {
	pdf_text "${output}" | grep -qF -- "$1"
}

# Succeed when the text of the PDF matches an extended regular expression.
# $1 pattern.
pdf_matches() {
	pdf_text "${output}" | grep -qE -- "$1"
}

# Answer the number of the first line of the PDF text that holds a fixed string, or nothing.
# $1 string.
line_of() {
	pdf_text "${output}" | grep -nF -- "$1" | head -n 1 | cut -d: -f1
}

# Succeed when each fixed string first shows on a later line than the one before.
# $@ strings, in the expected order.
in_order() {
	local previous=0 line item
	for item in "$@"; do
		line="$(line_of "${item}")"
		[ -n "${line}" ] && [ "${line}" -gt "${previous}" ] || return 1
		previous="${line}"
	done
}

# Succeed when the lists of figures and tables come before the body and list each caption.
lists_of_floats() {
	pdf_has 'List of Figures' && pdf_has 'List of Tables' &&
		in_order 'List of Figures' 'The first grey rectangle.' 'The second grey rectangle.' 'List of Tables' \
			'Patients by arm.' 'Figure 1: The first grey rectangle.' &&
		[ "$(pdf_text "${output}" | grep -cF 'The second grey rectangle.')" -eq 2 ]
}

# Succeed when every page of the PDF carries the watermark text.
watermark_every_page() {
	local pages page
	pages="$(pdf_page_count "${output}")"
	[ "${pages}" -ge 4 ] || return 1
	for ((page = 1; page <= pages; page++)); do
		pdftotext -f "${page}" -l "${page}" "${output}" - | tr -d '[:space:]' | grep -qF DRAFT || return 1
	done
}

# Succeed when the appendix is lettered: heading, sub-heading, figure, equation and reference.
appendix_lettered() {
	pdf_has 'Appendix A: Extra analyses' &&
		pdf_matches '(^|[[:space:]])A\.1[[:space:]]+Data sources' &&
		pdf_has 'Figure A.1: An appendix grey rectangle.' &&
		pdf_has '(A.1)' &&
		pdf_text "${output}" | tr -s '[:space:]' ' ' | grep -qE 'Figure A\.1, Equation \(A\.1\), .* and Appendix A\.'
}

# Succeed when the supplementary section and its floats are numbered S1.
supplementary_s1() {
	pdf_matches '(^|[[:space:]])S1[[:space:]]+Supplementary material' &&
		pdf_has 'Figure S1: A supplementary grey rectangle.' &&
		pdf_has 'Table S1: Supplementary patients by arm.'
}

# Succeed when the body keeps flat numbers and comes first, then the appendix, then the supplementary section.
parts_at_the_end() {
	pdf_has 'Figure 1: A body grey rectangle.' &&
		in_order 'Figure 1: A body grey rectangle.' 'Figure A.1: An appendix grey rectangle.' \
			'Figure S1: A supplementary grey rectangle.'
}

# Succeed when the figures and the equation carry the number of their section.
numbered_by_chapter() {
	pdf_has 'Figure 1.1: A first grey rectangle.' &&
		pdf_has 'Figure 2.1: A second grey rectangle.' &&
		pdf_has '(1.1)' &&
		pdf_text "${output}" | tr -s '[:space:]' ' ' | grep -qF 'See Figure 1.1, Figure 2.1 and Equation (1.1).'
}

# Succeed when the figures keep flat numbers, with no chapter prefix of 0.
flat_without_numbered_headings() {
	pdf_has 'Figure 1: A first grey rectangle.' &&
		pdf_has 'Figure 2: A second grey rectangle.' &&
		! pdf_has 'Figure 0.'
}

# Succeed when the body and part headings are numbered and the part sub-headings are not.
part_sub_headings_unnumbered() {
	pdf_matches '^[[:space:]]*1[[:space:]]+Results' &&
		pdf_has 'Appendix A: Extra' &&
		pdf_matches '^[[:space:]]*S1[[:space:]]+More' &&
		pdf_matches '^[[:space:]]*Sub one' &&
		pdf_matches '^[[:space:]]*Sub two' &&
		! pdf_matches '(A\.1|S1\.1)[[:space:]]+Sub'
}

# Succeed when the supplementary chapter of the book reads S1, with its figure S1 and its kicker,
# and the body chapter keeps its number and its flat figure number.
book_supplementary() {
	pdf_has 'Figure S1: A supplementary grey rectangle.' &&
		pdf_has 'Figure 1: A body grey rectangle.' &&
		pdf_matches '^[[:space:]]*1[[:space:]]+Results' &&
		pdf_matches '^[[:space:]]*S1[[:space:]]+Extra material' &&
		pdf_text "${output}" | tr -d '[:space:]' | grep -qF 'SUPPLEMENTARYS1Inthischapter' &&
		pdf_matches '(^|[[:space:]])S1\.1[[:space:]]+Extra figure'
}

# Succeed when the book appendix stays lettered, with A.1 sections and the Appendix kicker.
book_appendix() {
	pdf_matches '^[[:space:]]*A[[:space:]]+Listings' &&
		pdf_matches '(^|[[:space:]])A\.1[[:space:]]+Subject listings' &&
		pdf_text "${output}" | tr -d '[:space:]' | grep -qF 'APPENDIXAInthischapter'
}

case "${1:-}" in
list-of)
	expect "list-of-floats" "a list of figures and a list of tables before the body, with each caption" lists_of_floats
	expect "list-of-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
watermark)
	expect "watermark-every-page" "the DRAFT watermark on every page of the full report" watermark_every_page
	expect "watermark-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
sections)
	expect "sections-appendix" "Appendix A: Extra analyses, A.1 Data sources, Figure A.1, (A.1) and a reference to Appendix A" appendix_lettered
	expect "sections-supplementary" "S1 Supplementary material, Figure S1 and Table S1" supplementary_s1
	expect "sections-order" "flat body numbers, then the appendix, then the supplementary section" parts_at_the_end
	expect "sections-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
chapters)
	expect "chapters-numbering" "Figure 1.1, Figure 2.1 and equation (1.1)" numbered_by_chapter
	expect "chapters-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
chapters-unnumbered)
	expect "chapters-unnumbered-flat" "Figure 1 and Figure 2, and no Figure 0." flat_without_numbered_headings
	expect "chapters-unnumbered-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
sections-unnumbered)
	expect "sections-unnumbered-sub-headings" "1 Results, Appendix A: Extra, S1 More, and unnumbered Sub one and Sub two" part_sub_headings_unnumbered
	expect "sections-unnumbered-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
book)
	expect "book-supplementary" "the S1 chapter, its S1.1 section, Figure S1 and the Supplementary S1 kicker" book_supplementary
	expect "book-appendix" "the lettered appendix, A.1 sections and the Appendix A kicker" book_appendix
	expect "book-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
