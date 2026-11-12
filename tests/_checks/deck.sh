#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the slide types of a Reveal.js deck, read from the HTML, from a
# headless browser and from axe-core.
#
# Usage: deck.sh <preset>              slide types, footer, motif, closing slide, axe and painted contrast
#        deck.sh long-title <preset>   title, section and closing text clear of the motif
#        deck.sh dark <preset>         axe on a brand-mode: dark deck
#        deck.sh closing-refs          the bibliography stays off the closing slide
#
# Exits 77 for a format other than Reveal.js.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = revealjs ] || skip_format deck.sh
need python3

readonly SPEAKER_EVENT='Mickaël Canouil · useR! 2026 · Warwick'
readonly TALK_TITLE='Quarto extensions'
readonly CLOSING_LINKS=('mickael.canouil.fr' '@mickael.canouil.fr' 'github.com/mcanouil')
readonly LICENCE='Slides: m.canouil.dev/user2026 · CC BY 4.0'

# Answer one line per slide of the deck, tab separated: id, classes,
# data-background-gradient, data-background-color, data-footer, data-state,
# motif count, count of motifs without aria-hidden="true", link count, text.
slide_table() {
	python3 -I - "${output}" <<'PY'
import sys
from html.parser import HTMLParser

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


class Slides(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.slides = []
        self.in_slides = 0
        self.depth = 0
        self.skip = 0

    def current(self):
        for item in reversed(self.stack):
            if item is not None:
                return item
        return None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = (attrs.get("class") or "").split()
        if tag in VOID:
            return
        self.depth += 1
        if tag == "div" and "slides" in classes and not self.in_slides:
            self.in_slides = self.depth
        if tag in ("script", "style", "aside"):
            self.skip += 1
        slide = None
        if self.in_slides and tag == "section" and (attrs.get("id") or "slide" in classes or "quarto-title-block" in classes):
            slide = {
                "id": attrs.get("id") or "",
                "classes": " ".join(classes),
                "gradient": attrs.get("data-background-gradient") or "",
                "colour": attrs.get("data-background-color") or "",
                "footer": attrs.get("data-footer") or "",
                "state": attrs.get("data-state") or "",
                "motifs": 0,
                "exposed": 0,
                "links": 0,
                "text": [],
            }
            self.slides.append(slide)
        self.stack.append(slide)
        owner = self.current()
        if owner is not None:
            if tag == "svg" and "mc-motif" in classes:
                owner["motifs"] += 1
                if attrs.get("aria-hidden") != "true":
                    owner["exposed"] += 1
            if tag == "a":
                owner["links"] += 1

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if tag in ("script", "style", "aside"):
            self.skip = max(0, self.skip - 1)
        if self.stack:
            self.stack.pop()
        if self.in_slides == self.depth:
            self.in_slides = 0
        self.depth -= 1

    def handle_data(self, data):
        owner = self.current()
        if owner is not None and not self.skip:
            owner["text"].append(data)


parser = Slides()
with open(sys.argv[1], encoding="utf-8") as handle:
    parser.feed(handle.read())
for slide in parser.slides:
    text = " ".join(" ".join(slide["text"]).split())
    print("\t".join([slide["id"], slide["classes"], slide["gradient"], slide["colour"], slide["footer"],
                     slide["state"], str(slide["motifs"]), str(slide["exposed"]), str(slide["links"]), text]))
PY
}

# Answer the row of one slide.
# $1 slide id.
slide_row() {
	awk -F '\t' -v id="$1" '$1 == id' <<<"${slides}"
}

# Answer one field of the row of a slide.
# $1 slide id. $2 field number.
slide_field() {
	slide_row "$1" | awk -F '\t' -v n="$2" '{ print $n }'
}

# Succeed when a slide carries a class.
# $1 slide id. $2 class.
slide_has_class() {
	[[ " $(slide_field "$1" 2) " == *" $2 "* ]]
}

# Succeed when a slide is on the ground: the ground class, the ground gradient
# of the preset, no footer and no slide number.
# $1 slide id. $2 preset.
on_ground() {
	local gradient
	gradient="$(slide_field "$1" 3)"
	slide_has_class "$1" mc-ground &&
		[[ "${gradient}" == *"$(preset_value "$2" dark ground-1)"* ]] &&
		[[ "${gradient}" == *"$(preset_value "$2" dark ground-2)"* ]]
}

# Succeed when the title slide, both section slides and the closing slide are
# on the ground, and no other slide is.
# $1 preset.
ground_slides() {
	local id
	for id in title-slide brand-presets checks mc-closing; do
		on_ground "${id}" "$1" || return 1
	done
	[ "$(awk -F '\t' '$2 ~ /(^| )mc-ground( |$)/' <<<"${slides}" | wc -l | tr -d ' ')" = 4 ]
}

# Succeed when the title and closing slides hide the footer, the slide number
# and the menu button, and a section slide keeps them.
bare_slides() {
	local id
	for id in title-slide mc-closing; do
		[ "$(slide_field "${id}" 5)" = false ] && [[ " $(slide_field "${id}" 6) " == *" mc-bare "* ]] || return 1
	done
	[ -z "$(slide_field brand-presets 5)" ]
}

# Succeed when a slide with the dark class has the dark paper of the preset as its background colour.
# $1 preset.
dark_slide() {
	slide_has_class why-presets-after-dark dark &&
		[ "$(slide_field why-presets-after-dark 4)" = "$(preset_value "$1" dark paper)" ] &&
		! slide_has_class why-presets-after-dark mc-ground
}

# Succeed when the section slides carry their number, two digits for terminal.
# $1 preset.
section_numbers() {
	local first=1 second=2
	if [ "$1" = terminal ]; then
		first=01
		second=02
	fi
	has "${output}" "<p class=\"mc-section-number\">${first}</p>" &&
		has "${output}" "<p class=\"mc-section-number\">${second}</p>"
}

# Answer the text of a footer slot of the deck.
# $1 slot: left, centre or right.
footer_slot() {
	grep -oE "<span class=\"mc-slot mc-slot-$1[^\"]*\">[^<]*</span>" "${output}" | head -n 1 | sed -E 's/<[^>]+>//g'
}

# Succeed when the footer holds the three slots: speaker and event, talk
# title, and the slide number as "n / total".
footer_slots() {
	[ "$(grep -o 'class="mc-slot mc-slot-' "${output}" | wc -l | tr -d ' ')" = 3 ] &&
		[ "$(footer_slot left)" = "${SPEAKER_EVENT}" ] &&
		[ "$(footer_slot centre)" = "${TALK_TITLE}" ] &&
		has "${output}" 'class="mc-slot mc-slot-right mc-slot-page"' &&
		has "${output}" "slideNumber: 'c/t'"
}

# Succeed when every motif is hidden from assistive technology, and only the
# ground slides carry one.
motif_hidden() {
	[ "$(awk -F '\t' '{ n += $7 } END { print n + 0 }' <<<"${slides}")" = 4 ] &&
		[ "$(awk -F '\t' '{ n += $8 } END { print n + 0 }' <<<"${slides}")" = 0 ] &&
		[ -z "$(awk -F '\t' '$7 > 0 && $2 !~ /(^| )mc-ground( |$)/' <<<"${slides}")" ] &&
		[ "$(grep -o '<svg[^>]*class="mc-motif[^>]*>' "${output}" | grep -vc 'focusable="false"')" = 0 ]
}

# Succeed when the closing slide shows each link and the licence as text, with no link element.
closing_links_text() {
	local text link
	text="$(slide_field mc-closing 10)"
	for link in "${CLOSING_LINKS[@]}"; do
		[[ "${text}" == *"${link}"* ]] || return 1
	done
	[[ "${text}" == *"${LICENCE}"* ]] && [ "$(slide_field mc-closing 9)" = 0 ]
}

# Succeed when the title slide shows the event, the subtitle and the speaker.
title_slide() {
	local text
	text="$(slide_field title-slide 10)"
	[[ "${text}" == *'useR! 2026 · Warwick'* ]] && [[ "${text}" == *'Build, share and maintain your own formats'* ]] &&
		[[ "${text}" == *'Mickaël Canouil'* ]] && grep -qE 'class="mc-speaker-photo" src="data:image/svg\+xml;base64,[^"]+" alt="Portrait of Mickaël Canouil"' "${output}"
}

# Succeed when the last paragraph of the quote, without its dash, is the caption of the quote figure.
quote_attribution() {
	tr -s '\n' ' ' <"${output}" | grep -qE '<figcaption class="mc-quote-attribution"[^>]*> ?Mickaël Canouil, 2026 ?</figcaption> ?</figure>' &&
		lacks "${output}" '– Mickaël Canouil, 2026' && lacks "${output}" '-- Mickaël Canouil, 2026'
}

# Succeed when the bibliography is in the deck, and the closing slide holds none of it.
closing_without_refs() {
	has "${output}" 'id="refs"' && [[ "$(slide_field mc-closing 10)" != *'cohort study'* ]] &&
		[ "$(slide_field mc-closing 10)" = 'Thank you mickael.canouil.fr' ]
}

# Set browser_bin to a Chromium-based browser: CHROME_PATH, QUARTO_CHROMIUM,
# then the browsers installed on macOS and Linux. A hook that cannot find one stops.
find_browser() {
	local candidate
	for candidate in "${CHROME_PATH:-}" "${QUARTO_CHROMIUM:-}" \
		"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		"/Applications/Chromium.app/Contents/MacOS/Chromium" \
		"$(command -v chromium || true)" "$(command -v chromium-browser || true)" \
		"$(command -v google-chrome || true)" "$(command -v brave-browser || true)"; do
		if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
			browser_bin="${candidate}"
			return 0
		fi
	done
	printf 'Bail out! no Chromium-based browser found; set CHROME_PATH to one.\n'
	exit 1
}

# Run the probe of deck-probe.js on slides of the deck in a headless browser,
# and answer its lines: "<slide> shape x0 y0 x1 y1" for each motif shape,
# "<slide> text x0 y0 x1 y1" for each line box of text and each image, in slide
# pixels, and "<slide> colour <name> <ratio> <threshold>" for each text and
# mark that the probe reads.
# $@ slide ids.
probe_slides() {
	local probe="${output%.html}-probe.html"
	python3 -I - "${output}" "${probe}" "$(dirname "${BASH_SOURCE[0]}")/deck-probe.js" "$@" <<'PY'
import json
import sys

source, probe, script = sys.argv[1:4]
with open(script, encoding="utf-8") as handle:
    code = handle.read()
inject = "<script>window.MC_PROBE_SLIDES = %s;</script><script>%s</script>" % (json.dumps(sys.argv[4:]), code)
with open(source, encoding="utf-8") as handle:
    html = handle.read()
with open(probe, "w", encoding="utf-8") as handle:
    handle.write(html.replace("</body>", inject + "</body>"))
PY
	"${browser_bin}" --headless --disable-gpu --hide-scrollbars --window-size=1600,900 \
		--virtual-time-budget=20000 --dump-dom "file://${probe}" 2>/dev/null |
		python3 -I -c 'import html, re, sys; m = re.search(r"<pre id=\"mc-probe\">(.*?)</pre>", sys.stdin.read(), re.S); print(html.unescape(m.group(1)) if m else "")'
	rm -f "${probe}"
}

# Succeed when the text of a slide is clear of its motif: every line box and
# image is below or left of the bounding box of every motif shape. A slide with
# no motif or no text fails.
# $1 slide id.
text_clear_of_motif() {
	local boxes
	boxes="$(awk -v id="$1" '$1 == id' <<<"${probe_lines}")"
	grep -q ' shape ' <<<"${boxes}" && grep -q ' text ' <<<"${boxes}" &&
		awk '
			$2 == "shape" { n++; sx0[n] = $3; sy1[n] = $6 }
			$2 == "text" { for (i = 1; i <= n; i++) if (!($4 >= sy1[i] || $5 <= sx0[i])) { print "# overlap: " $0; bad = 1 } }
			END { exit bad }
		' <<<"${boxes}"
}

# Succeed when every text and mark that the probe read meets its contrast
# ratio (4.5:1 for text, 3:1 for large text and marks), and the probe read the
# kicker, the footer and the menu button.
colours_readable() {
	local colours
	colours="$(awk '$2 == "colour"' <<<"${probe_lines}")"
	grep -q ' \.mc-kicker ' <<<"${colours}" && grep -q ' footer' <<<"${colours}" && grep -q ' menu-button ' <<<"${colours}" &&
		awk '$4 + 0 < $5 + 0 { print "# low contrast: " $0; bad = 1 } END { exit bad }' <<<"${colours}"
}

# Succeed when axe-core finds no violation in the deck. The scan runs on a
# copy, so its artefacts stay out of the tests directory.
axe_clean() {
	local scratch name findings
	scratch="$(mktemp -d)"
	name="$(basename "${output}")"
	command cp -R "${output}" "${output%.html}_files" "${scratch}/"
	(cd "${scratch}" && quarto call axe . --pages "${name}" --quiet --fail-on minor >/dev/null 2>&1) || {
		findings="${scratch}/_axe-checks/report.md"
		[ -f "${findings}" ] && sed -n '/## New findings/,$p' "${findings}" | head -n 40 | sed 's/^/# /'
		rm -rf "${scratch}"
		return 1
	}
	rm -rf "${scratch}"
}

slides="$(slide_table)"

case "${1:-}" in
gold | mono | quarto | terminal)
	expect "deck-ground-slides-${1}" "title, section and closing slides, and only them, on the ${1} ground" ground_slides "$1"
	expect "deck-bare-slides-${1}" "no footer and no slide number on the title and closing slides" bare_slides
	expect "deck-dark-class-${1}" "the .dark slide on the ${1} dark paper" dark_slide "$1"
	expect "deck-section-number-${1}" "the number of each section slide" section_numbers "$1"
	expect "deck-title-slide-${1}" "event, subtitle, speaker and photo on the title slide" title_slide
	expect "deck-footer-slots-${1}" "speaker · event | talk title | slide n / total" footer_slots
	expect "deck-motif-hidden-${1}" "four motifs, on the ground slides only, all aria-hidden and not focusable" motif_hidden
	expect "deck-closing-links-text-${1}" "closing links and licence as text, no link element" closing_links_text
	expect "deck-quote-attribution-${1}" "the attribution of the quote without its dash" quote_attribution
	expect "deck-axe-light-${1}" "no axe-core violation in the ${1} deck" axe_clean
	find_browser
	probe_lines="$(probe_slides title-slide brand-presets why-presets one-rule why-presets-after-dark mc-closing)"
	expect "deck-computed-contrast-${1}" "4.5:1 for text, 3:1 for large text and marks, as the browser paints them" colours_readable
	;;
long-title)
	find_browser
	probe_lines="$(probe_slides title-slide a-section-title-long-enough-to-wrap-over-several-lines-of-the-slide mc-closing)"
	expect "long-title-no-overlap-title-${2:?long-title needs a preset}" "title slide text clear of the ${2} motif" text_clear_of_motif title-slide
	expect "long-title-no-overlap-section-${2}" "section slide text clear of the ${2} motif" text_clear_of_motif a-section-title-long-enough-to-wrap-over-several-lines-of-the-slide
	expect "long-title-no-overlap-closing-${2}" "closing slide text clear of the ${2} motif" text_clear_of_motif mc-closing
	;;
closing-refs)
	expect "deck-closing-no-refs" "the bibliography in the deck, and not on the closing slide" closing_without_refs
	;;
dark)
	expect "deck-axe-dark-${2:?dark needs a preset}" "no axe-core violation in the ${2} brand-mode: dark deck" axe_clean
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
