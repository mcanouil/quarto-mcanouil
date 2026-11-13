#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ and verapdf_bin are set by lib.sh
set -euo pipefail

# Check hook: the workshop type in its three formats, from one session file.
#
# Usage: workshop.sh <preset>    HTML page, PDF handout (solutions at the end) and deck of one preset
#        workshop.sh inline      PDF handout with each solution in its exercise
#        workshop.sh hide        PDF handout without the solutions
#
# The HTML page goes to "html.sh workshop" and the deck to "deck.sh workshop".
# This hook checks the PDF handout: the block labels, the session kicker and
# footer, where the solutions are, the page links to them, the code without
# ligatures, and PDF/UA-1 with veraPDF.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${format}" in
html) exec bash "$(dirname "${BASH_SOURCE[0]}")/html.sh" workshop "$@" ;;
revealjs) exec bash "$(dirname "${BASH_SOURCE[0]}")/deck.sh" workshop "$@" ;;
typst) ;;
*) skip_format workshop.sh ;;
esac
need pdftotext

readonly SOLUTION_1='The first solution sets two formats in the front matter.'
readonly SOLUTION_2='The second solution labels the figure'
readonly EXERCISE_1='Exercise 2.1 · 15 min · solo'
readonly EXERCISE_2='Exercise 2.2 · 20 min · pairs'
readonly CHECKPOINT='Your document renders to HTML and to Typst'

text="$(pdftotext "${output}" - | tr -s '[:space:]' ' ')"

# Answer the first page of the PDF whose text holds a string, or nothing.
# $1 string.
page_of() {
	local page pages
	pages="$(pdf_page_count "${output}")"
	for ((page = 1; page <= pages; page++)); do
		if pdftotext -f "${page}" -l "${page}" "${output}" - | tr -s '[:space:]' ' ' | grep -qF -- "$1"; then
			printf '%s' "${page}"
			return 0
		fi
	done
}

# Answer the position of a string in the text of the PDF, or -1.
# $1 string.
position_of() {
	python3 -I -c 'import sys; print(sys.argv[1].find(sys.argv[2]))' "${text}" "$1"
}

# Succeed when the labels of the blocks show as text.
labels_shown() {
	local label status=0
	for label in Objectives Prerequisites "${EXERCISE_1}" "${EXERCISE_2}" Checkpoint; do
		grep -qF -- "${label}" <<<"${text}" || {
			printf '# missing label: %s\n' "${label}"
			status=1
		}
	done
	return "${status}"
}

# Succeed when page 1 shows the session as the kicker, the duration, and the
# event and the session in the footer.
session_shown() {
	local first footer
	first="$(pdf_page_text "${output}" 1 | tr -s '[:space:]' ' ')"
	footer="$(pdf_footer "${output}" 1)"
	if grep -qiF 'Session 2 of 7' <<<"${first}" && grep -qF '90 min' <<<"${first}" &&
		grep -qF 'Mastering Quarto CLI' <<<"${footer}" && grep -qF 'Session 2' <<<"${footer}"; then
		return 0
	fi
	printf '# page 1 footer: %s\n' "${footer}"
	return 1
}

# Succeed when each exercise page has the link "Solution: page n", n is the
# page of its solution, and every solution comes after the last block of the
# session (the checkpoint).
# $1 solution sentence. $2 exercise label.
solution_at_end() {
	local solution_page exercise_page
	solution_page="$(page_of "$1")"
	exercise_page="$(page_of "$2")"
	[ -n "${solution_page}" ] && [ -n "${exercise_page}" ] || {
		printf '# solution page "%s", exercise page "%s"\n' "${solution_page}" "${exercise_page}"
		return 1
	}
	pdftotext -f "${exercise_page}" -l "${exercise_page}" "${output}" - | tr -s '[:space:]' ' ' |
		grep -qF "Solution: page ${solution_page}" || {
		printf '# no "Solution: page %s" on page %s\n' "${solution_page}" "${exercise_page}"
		return 1
	}
	[ "$(position_of "$1")" -gt "$(position_of "${CHECKPOINT}")" ] || {
		printf '# the solution comes before the checkpoint\n'
		return 1
	}
}

# Succeed when the solution links are links to the solution headings in the
# Typst source.
solution_links() {
	grep -qE 'mc-ws-solution-link\(<mc-ws-solution-2-1>\)' "${typ}" &&
		grep -qE '<mc-ws-solution-2-1>' "${typ}" && grep -qE 'mc-ws-solution-link\(<mc-ws-solution-2-2>\)' "${typ}"
}

# Succeed when each solution is printed in its exercise, before the next one,
# with no page link.
solutions_inline() {
	local one two
	one="$(position_of "${SOLUTION_1}")"
	two="$(position_of "${SOLUTION_2}")"
	[ "${one}" -gt "$(position_of "${EXERCISE_1}")" ] && [ "${one}" -lt "$(position_of "${EXERCISE_2}")" ] &&
		[ "${two}" -gt "$(position_of "${EXERCISE_2}")" ] && [ "${two}" -lt "$(position_of "${CHECKPOINT}")" ] &&
		! grep -qF 'Solution: page' <<<"${text}"
}

# Succeed when no solution and no page link is in the PDF.
solutions_hidden() {
	! grep -qF -- "${SOLUTION_1}" <<<"${text}" && ! grep -qF -- "${SOLUTION_2}" <<<"${text}" &&
		! grep -qF 'Solution' <<<"${text}"
}

# Succeed when the Typst raw show rule turns ligatures and contextual
# alternates off.
no_ligatures() {
	grep -qE 'show raw: set text\(.*ligatures: false' "${typ}" && grep -qE 'show raw: set text\(.*"calt": 0' "${typ}"
}

case "${1:-}" in
gold | mono | quarto | terminal)
	expect "workshop-pdf-labels-${1}" "the block labels as text, with the exercise number, duration and format" labels_shown
	expect "workshop-pdf-session-${1}" "the session kicker and duration on page 1, the event and the session in the footer" session_shown
	expect "workshop-pdf-end-${1}" "the first solution after the checkpoint, behind a \"Solution: page n\" link on its exercise page" \
		solution_at_end "${SOLUTION_1}" "${EXERCISE_1}"
	expect "workshop-pdf-end-second-${1}" "the second solution after the checkpoint, behind its page link" \
		solution_at_end "${SOLUTION_2}" "${EXERCISE_2}"
	expect "workshop-pdf-end-links-${1}" "the page links point at the solution headings" solution_links
	expect "no-ligatures-pdf-${1}" "ligatures: false and calt off in the Typst raw show rule" no_ligatures
	find_verapdf
	expect "workshop-pdf-ua1-${1}" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
inline)
	expect "workshop-pdf-inline" "each solution inside its exercise, and no page link" solutions_inline
	find_verapdf
	expect "workshop-pdf-inline-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
hide)
	expect "workshop-pdf-hide" "no solution text and no solution link" solutions_hidden
	expect "workshop-pdf-hide-labels" "the block labels still shown" labels_shown
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
