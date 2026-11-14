#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ and verapdf_bin are set by lib.sh
set -euo pipefail

# Check hook: the workshop type in its three formats, from one session file.
#
# Usage: workshop.sh <preset>    HTML page, PDF handout (solutions at the end) and deck of one preset
#        workshop.sh inline      PDF handout with each solution in its exercise
#        workshop.sh hide        PDF handout without the solutions
#        workshop.sh solution-attrs   a solution keeps its heading, name, identifier, class and data attribute
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

# Succeed when the HTML solution keeps its identifier, its extra class, its
# data attribute and its leading heading, and its name joins its label.
# $1 the element of the solution: details (page) or div (deck).
attrs_kept_html() {
	python3 -I - "${output}" "$1" <<'PY'
import re
import sys

html = open(sys.argv[1], encoding="utf-8").read()
tag = sys.argv[2]
found = re.search(r"<%s\b([^>]*\bmc-ws-solution\b[^>]*)>(.*?)</%s>" % (tag, tag), html, re.S)
problems = []
if not found:
    sys.exit("# no %s.mc-ws-solution" % tag)
attrs, body = found.groups()
for want in ('id="worked-callout"', 'data-level="easy"'):
    if want not in attrs:
        problems.append("missing %s in <%s%s>" % (want, tag, attrs))
classes = re.search(r'class="([^"]*)"', attrs).group(1).split()
if "worked" not in classes or "solution" not in classes:
    problems.append("classes %r, expected worked and solution" % classes)
if re.search(r"\bname=", attrs):
    problems.append("the name attribute is still on the element")
label = re.search(r"<(?:summary|p class=\"mc-ws-label\"[^>]*)>(.*?)</(?:summary|p)>", body, re.S)
if not label or label.group(1).strip() != "Solution · Worked answer":
    problems.append("label %r, expected 'Solution · Worked answer'" % (label.group(1) if label else None))
if not re.search(r"<h3\b[^>]*>.*?Step by step.*?</h3>", body, re.S):
    problems.append("no h3 Step by step in the solution")
if "The worked answer wraps the text" not in body:
    problems.append("the solution text is missing")
second = re.search(r'<%s\b([^>]*\bid="sol-a"[^>]*)>(.*?)</%s>' % (tag, tag), html, re.S)
if not second or "mc-ws-solution" not in second.group(1):
    problems.append("no %s.mc-ws-solution with id sol-a" % tag)
elif "The second answer keeps the id" not in second.group(2):
    problems.append("the text of the sol-a solution is missing")
if re.search(r'class="[^"]*\bproof\b', html):
    problems.append("a solution was rendered as a Quarto proof")
if "mc-ws-sol-" in html:
    problems.append("the private id prefix leaked into the output")
for problem in problems:
    print("# " + problem)
sys.exit(1 if problems else 0)
PY
}

# Succeed when the solution with the id sol-a is at the end of the handout,
# and its heading carries the label <sol-a>, as the author wrote the id.
# $1 text of the PDF.
solution_sol_id() {
	grep -qF 'Solution 2.2 The second answer keeps the id' <<<"$1" && grep -qE '<sol-a>' "${typ}" &&
		! grep -qF 'mc-ws-sol-' "${typ}"
}

if [ "${1:-}" = solution-attrs ]; then
	case "${format}" in
	html) expect "workshop-solution-attrs-html" "the details keeps id, class, data attribute and heading, label with the name" attrs_kept_html details ;;
	revealjs) expect "workshop-solution-attrs-deck" "the veil block keeps id, class, data attribute and heading, label with the name" attrs_kept_html div ;;
	typst)
		need pdftotext
		attrs_text="$(pdftotext "${output}" - | tr -s '[:space:]' ' ')"
		expect "workshop-solution-attrs-pdf" "the end heading with the name, then the solution heading and text" \
			grep -qE 'Solution 2\.1 · Worked answer Step by step The worked answer wraps the text' <<<"${attrs_text}"
		expect "workshop-solution-sol-id-pdf" "the sol-a solution at the end, with its id as a Typst label" \
			solution_sol_id "${attrs_text}"
		find_verapdf
		expect "workshop-solution-attrs-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
		;;
	*) skip_format workshop.sh ;;
	esac
	tap_done
	exit
fi

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
