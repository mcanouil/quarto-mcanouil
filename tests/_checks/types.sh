#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the layout of each document type, read from the text of the PDF.
#
# Usage: types.sh compact <preset>
#        types.sh compact-short <preset>
#        types.sh full <preset>
#        types.sh full-depth
#        types.sh full-flows
#        types.sh long-title <preset>
#        types.sh book
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format types.sh
need pdftotext

# Succeed when page 1 holds the title, the abstract and the first level 1 heading, so there is no cover.
compact_first_page() {
	local text
	text="$(pdf_page_text "${output}" 1)"
	grep -qF 'Compact report' <<<"${text}" &&
		grep -qF 'Abstract' <<<"${text}" &&
		grep -qF 'This abstract opens page 1.' <<<"${text}" &&
		grep -qE 'Introduction' <<<"${text}"
}

# Succeed when two level 1 headings both sit on page 1.
compact_headings_inline() {
	local text
	text="$(pdf_page_text "${output}" 1)"
	grep -qE 'Introduction' <<<"${text}" && grep -qE 'Study design' <<<"${text}"
}

# Answer the words of page 1 as "xMin yMin xMax yMax word" in points.
page1_words() {
	pdftotext -bbox -f 1 -l 1 "${output}" - |
		sed -nE 's/.*<word xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)">(.*)<\/word>.*/\1 \2 \3 \4 \5/p'
}

# Succeed when the abstract label starts less than 15 mm below the author line.
compact_no_gap() {
	local author_bottom abstract_top
	author_bottom="$(page1_words | awk '$5 == "Author" { print $4; exit }')"
	abstract_top="$(page1_words | awk '$5 == "Abstract" { print $2; exit }')"
	[ -n "${author_bottom}" ] && [ -n "${abstract_top}" ] &&
		awk -v top="${abstract_top}" -v bottom="${author_bottom}" 'BEGIN { exit !((top - bottom) / 72 * 25.4 < 15) }'
}

# Answer the extent of the shapes of the motif of a preset, as "left bottom" in view box units (0 to 100).
# $1 preset.
motif_extent() {
	local name
	name="$(awk '/^motif:/ { print $2 }' "${ext_dir}/presets/$1.yml")"
	typst_value "${typ}" mc-motif-extent "mc-motif-extent(\"${name}\").values().map(str).join(\" \")" | tr -d '"'
}

# Succeed when no word that starts above the bottom of the shapes of the corner motif reaches into them.
# The motif is 80 mm wide, as in typst/types/report.typ.
# $1 preset.
clear_of_motif() {
	local width extent
	width="$(pdftotext -bbox -f 1 -l 1 "${output}" - | sed -nE 's/.*<page width="([0-9.]+)".*/\1/p')"
	extent="$(motif_extent "$1")"
	[ -n "${width}" ] && [ -n "${extent}" ] &&
		page1_words | awk -v width="${width}" -v extent="${extent}" '
			BEGIN {
				split(extent, e, " ")
				size = 80 / 25.4 * 72
				left = width - (100 - e[1]) / 100 * size
				bottom = e[2] / 100 * size
			}
			$2 < bottom && $3 > left { bad = 1 }
			END { exit bad }'
}

# Succeed when page 1 holds the title, the footer and at least three lines of paragraph.
first_paragraph_long() {
	[ "$(pdf_page_text "${output}" 1 | grep -c .)" -ge 5 ]
}

# Answer the number of the first page of the PDF whose text matches an extended regular expression, or nothing.
# $1 regular expression.
page_matching() {
	local page total
	total="$(pdf_page_count "${output}")"
	for ((page = 1; page <= total; page++)); do
		if pdf_page_text "${output}" "${page}" | grep -qE -- "$1"; then
			printf '%d' "${page}"
			return 0
		fi
	done
}

# Answer the lines of a page that are entries of a contents list: a title, dot leaders and a page
# number. A few characters may sit between the leaders and the number: the outline of Typst puts a
# word joiner there.
# $1 page number.
contents_entries() {
	pdf_page_text "${output}" "$1" | grep -E '[^.][[:space:]]*\.{3,}[^.0-9]{0,6}[0-9]+[[:space:]]*$' || true
}

# Succeed when the pages come in the order cover, contents, divider, chapter contents, body, and the
# last page is the closing page.
full_structure() {
	local total
	total="$(pdf_page_count "${output}")"
	pdf_page_text "${output}" 1 | grep -qF 'Clinical study report' &&
		! pdf_page_text "${output}" 1 | grep -qF 'In this chapter' &&
		pdf_page_text "${output}" 2 | grep -qF 'Contents' &&
		[ "$(contents_entries 2 | grep -c 'Introduction')" -eq 1 ] &&
		pdf_page_text "${output}" 3 | grep -qE '^[[:space:]]*1[[:space:]]*$' &&
		pdf_page_text "${output}" 3 | grep -qF 'Introduction' &&
		pdf_page_text "${output}" 3 | grep -qF 'Why the study was run' &&
		pdf_page_text "${output}" 4 | grep -qF 'In this chapter' &&
		[ "$(contents_entries 4 | grep -c 'Background')" -eq 1 ] &&
		pdf_page_text "${output}" 5 | grep -qF 'The study followed a cohort' &&
		pdf_page_text "${output}" "${total}" | grep -qF 'Colophon'
}

# Succeed when the divider of the second chapter takes its introduction from the first paragraph.
divider_intro_paragraph() {
	local page
	page="$(page_matching '^[[:space:]]*2[[:space:]]*$')"
	[ -n "${page}" ] && pdf_page_text "${output}" "${page}" | grep -qF 'How the study was set up'
}

# Succeed when the divider of the second chapter shows the first sentence of its first paragraph,
# with its citation, and the second sentence stays in the body.
divider_intro_first_sentence() {
	local page
	page="$(page_matching '^[[:space:]]*2[[:space:]]*$')"
	[ -n "${page}" ] &&
		pdf_page_text "${output}" "${page}" | tr -s '[:space:]' ' ' | grep -qE 'as in earlier work \[1\]\.' &&
		! pdf_page_text "${output}" "${page}" | grep -qF 'The second sentence' &&
		pdf_text "${output}" | tr -s '[:space:]' ' ' | grep -qF 'The second sentence of the opening paragraph'
}

# Succeed when the references heading and the first reference are on the same page.
references_same_page() {
	local page
	page="$(page_matching '^[[:space:]]*References[[:space:]]*$')"
	[ -n "${page}" ] && pdf_page_text "${output}" "${page}" | grep -qF '[1] J. Doe'
}

# Succeed when the closing page holds the contact, the ORCID, the licence and the colophon.
closing_page() {
	local text
	text="$(pdf_page_text "${output}" "$(pdf_page_count "${output}")")"
	grep -qF 'Contact' <<<"${text}" && grep -qF 'ana@example.org' <<<"${text}" &&
		grep -qF '0000-0002-0724-1961' <<<"${text}" &&
		grep -qF 'Licence' <<<"${text}" && grep -qF 'CC BY 4.0' <<<"${text}" &&
		grep -qF 'Colophon' <<<"${text}"
}

# Answer the number of text lines of a page that are links to a page of the document, and the number
# of text lines that hold a link and also text outside the link.
# $1 page number.
page_link_lines() {
	pdftohtml -xml -i -stdout -f "$1" -l "$1" "${output}" 2>/dev/null | awk '
		/<text / {
			match($0, /top="[0-9]+"/)
			top = substr($0, RSTART + 5, RLENGTH - 6)
			if ($0 ~ /<a href="[^"]*#[0-9]+">/) { linked[top] = 1 } else { plain[top] = 1 }
		}
		END {
			for (top in linked) { n++; if (top in plain) { mixed++ } }
			printf "%d %d\n", n, mixed
		}'
}

# Succeed when every entry of a chapter contents page is a link to a page of the document.
# $1 page number of the chapter contents page.
chapter_toc_links() {
	local entries links mixed
	entries="$(contents_entries "$1" | grep -c .)"
	read -r links mixed <<<"$(page_link_lines "$1")"
	[ "${entries}" -ge 3 ] && [ "${links}" -eq "${entries}" ] && [ "${mixed}" -eq 0 ]
}

# Succeed when appendices are numbered A.1, supplementary sections I.1, and references are unnumbered,
# in the order references, appendices, supplementary sections.
appendix_numbering() {
	local text order
	text="$(pdf_text "${output}")"
	grep -qE '(^|[[:space:]])A\.1[[:space:]]+Subject listings' <<<"${text}" &&
		grep -qE '(^|[[:space:]])I\.1[[:space:]]+Extra table' <<<"${text}" &&
		! grep -qE '[0-9A-Z][[:space:]]+References' <<<"${text}" &&
		order="$(contents_entries 2 | grep -oE '(References|A[[:space:]]+Listings|I[[:space:]]+Extra tables)' | tr -s ' ' | tr '\n' '|')" &&
		[ "${order}" = 'References|A Listings|I Extra tables|' ]
}

# Succeed when the first chapter contents page lists the sections and hides the subsections.
chapter_toc_depth_one() {
	local entries
	entries="$(contents_entries 4)"
	grep -qF 'Background' <<<"${entries}" && grep -qF 'Objectives' <<<"${entries}" && ! grep -qF 'History' <<<"${entries}"
}

# Succeed when the second page of the chapter contents has no running header, as its first page.
chapter_toc_flows_no_header() {
	local page
	page="$(page_matching 'In this chapter')"
	[ -n "${page}" ] && ! pdf_page_text "${output}" $((page + 1)) | grep -qF 'Clinical study report'
}

# Succeed when the 40 entries of the chapter contents run over two pages.
chapter_toc_flows() {
	local page first second
	page="$(page_matching 'In this chapter')"
	[ -n "${page}" ] || return 1
	first="$(contents_entries "${page}" | grep -c 'Section')"
	second="$(contents_entries $((page + 1)) | grep -c 'Section')"
	[ "${first}" -gt 0 ] && [ "${second}" -gt 0 ] && [ $((first + second)) -eq 40 ]
}

# Succeed when no word of the cover reaches into the shapes of the cover motif or into the footer band.
# $1 preset.
long_title_clear() {
	local size width height extent
	size="$(typst_value "${typ}" mc-cover-motif-size 'mc-cover-motif-size.pt()')"
	width="$(pdftotext -bbox -f 1 -l 1 "${output}" - | sed -nE 's/.*<page width="([0-9.]+)" height="([0-9.]+)".*/\1/p')"
	height="$(pdftotext -bbox -f 1 -l 1 "${output}" - | sed -nE 's/.*<page width="([0-9.]+)" height="([0-9.]+)".*/\2/p')"
	extent="$(motif_extent "$1")"
	[ -n "${size}" ] && [ -n "${width}" ] && [ -n "${extent}" ] &&
		page1_words | grep -q ' clinical$' &&
		page1_words | awk -v width="${width}" -v height="${height}" -v size="${size}" -v extent="${extent}" '
			BEGIN {
				split(extent, e, " ")
				left = width - (100 - e[1]) / 100 * size
				bottom = e[2] / 100 * size
				band = height - 25 / 25.4 * 72
			}
			$2 < bottom && $3 > left { bad = 1 }
			$2 < band && $4 > band { bad = 1 }
			END { exit bad }'
}

# Succeed when the book has its cover, its contents, the divider and the contents page of its first
# chapter, and the closing page last.
book_structure() {
	local page
	page="$(page_matching 'In this chapter')"
	[ -n "${page}" ] &&
		pdf_page_text "${output}" 1 | grep -qF 'Clinical study report' &&
		! pdf_page_text "${output}" 1 | grep -qF 'Contents' &&
		[ "$(contents_entries 2 | grep -c 'Study objectives and design')" -eq 1 ] &&
		pdf_page_text "${output}" $((page - 1)) | grep -qE '^[[:space:]]*1[[:space:]]*$' &&
		pdf_page_text "${output}" $((page - 1)) | grep -qF 'Study objectives and design' &&
		pdf_page_text "${output}" "$(pdf_page_count "${output}")" | grep -qF 'Colophon'
}

# Succeed when the divider of a book chapter shows the description of its front matter.
book_description() {
	local page
	page="$(page_matching '^[[:space:]]*2[[:space:]]*$')"
	[ -n "${page}" ] && pdf_page_text "${output}" "${page}" | grep -qF 'The statistical methods, from the analysis sets'
}

# Succeed when the book "Appendices" part has a page of its own with no header and no page number.
book_appendices_divider() {
	local page text
	page="$(page_matching '^[[:space:]]*Appendices[[:space:]]*$')"
	[ -n "${page}" ] || return 1
	text="$(pdf_page_text "${output}" "${page}")"
	! grep -qF 'Clinical study report' <<<"${text}" && ! grep -qE '[0-9]+ / [0-9]+' <<<"${text}"
}

# Succeed when no page shows the front matter block of a chapter as a code window.
book_no_title_block() {
	! pdf_text "${output}" | grep -qi 'quarto-title-block'
}

# Succeed when the book appendices are lettered, A.1 for their sections, and the references are unnumbered.
book_appendix_numbering() {
	pdf_text "${output}" | grep -qE '(^|[[:space:]])A\.1[[:space:]]+Individual subject data listings' &&
		contents_entries 2 | grep -qE '^[[:space:]]*A[[:space:]]+Listings' &&
		contents_entries 2 | grep -qE '^[[:space:]]*References' &&
		! pdf_text "${output}" | grep -qE '[0-9A-Z][[:space:]]+References'
}

case "${1:-}" in
compact)
	expect "compact-first-page" "the title, the abstract and the first heading on page 1" compact_first_page
	expect "compact-headings-inline" "two level 1 headings on page 1" compact_headings_inline
	expect "compact-no-gap" "the abstract less than 15 mm below the author line" compact_no_gap
	expect "compact-clear-of-motif" "no text inside the shapes of the ${2:?compact needs a preset} motif" clear_of_motif "$2"
	;;
compact-short)
	expect "compact-clear-of-motif" "no text inside the shapes of the ${2:?compact-short needs a preset} motif" clear_of_motif "$2"
	expect "compact-short-paragraph" "a first paragraph of several lines, so a line can reach the motif" first_paragraph_long
	;;
full)
	expect "full-structure" "pages in the order cover, contents, divider, chapter contents, body, and the closing page last" full_structure
	expect "full-divider-intro" "the first paragraph of a chapter with no description on its divider" divider_intro_paragraph
	expect "full-divider-first-sentence" "only the first sentence, with its citation, on the divider" divider_intro_first_sentence
	expect "references-same-page" "the references heading and the first reference on the same page" references_same_page
	expect "full-closing-page" "the contact, the ORCID, the licence and the colophon on the last page" closing_page
	expect "chapter-toc-links" "one link annotation for each entry of the chapter contents page" chapter_toc_links 4
	expect "appendix-numbering" "appendices numbered A.1, supplementary sections I.1, unnumbered references, in that order" appendix_numbering
	;;
full-depth)
	expect "chapter-toc-depth" "the sections and not the subsections on the chapter contents page" chapter_toc_depth_one
	;;
full-flows)
	expect "chapter-toc-flows" "the 40 entries of the chapter contents over two pages" chapter_toc_flows
	expect "chapter-toc-flows-no-header" "no running header on the second chapter contents page" chapter_toc_flows_no_header
	;;
long-title)
	expect "long-title-no-overlap" "no cover word inside the shapes of the ${2:?long-title needs a preset} motif or in the footer band" long_title_clear "$2"
	;;
book)
	expect "book-structure" "cover, contents, the divider and the contents page of chapter 1, and the closing page last" book_structure
	expect "book-description" "the description of the chapter front matter on its divider" book_description
	expect "book-chapter-toc-links" "one link annotation for each entry of the first chapter contents page" \
		chapter_toc_links "$(page_matching 'In this chapter')"
	expect "book-appendices-divider" "the Appendices part on a divider page with no header and no page number" book_appendices_divider
	expect "book-no-title-block" "no QUARTO-TITLE-BLOCK code window from a chapter front matter" book_no_title_block
	expect "book-appendix-numbering" "lettered appendices, A.1 sections and unnumbered references" book_appendix_numbering
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
