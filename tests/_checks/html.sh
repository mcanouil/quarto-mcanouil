#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, ext_dir and tests_dir are set by lib.sh
set -euo pipefail

# Check hook: the base of the HTML format, from the rendered page.
#
# Usage: html.sh title <preset>
#        html.sh subdir
#
# The title case checks the schemes, the landmarks, the skip link, the title
# block and its corner motif, the local fonts and the preset style rules of one
# preset, and runs axe-core on the page with quarto call axe. The motif
# geometry is measured in a headless Chromium browser: CHROME_PATH,
# QUARTO_CHROMIUM, Brave, Chrome or Chromium.
#
# Exits 77 for a format other than HTML.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = html ] || skip_format html.sh

# Answer the path of a stylesheet that the HTML output links, from its id.
# $1 id of the link element, for example quarto-bootstrap.
# $2 1 for the dark stylesheet (the one with quarto-color-alternate), 0 otherwise.
linked_css() {
	local href
	href="$(
		python3 -I - "${output}" "$1" "$2" <<'PY'
import re
import sys

html = open(sys.argv[1], encoding="utf-8").read()
for tag in re.findall(r"<link\b[^>]*>", html):
    if f'id="{sys.argv[2]}"' not in tag:
        continue
    dark = "quarto-color-alternate" in tag
    if dark == (sys.argv[3] == "1"):
        print(re.search(r'href="([^"]+)"', tag).group(1))
        break
PY
	)"
	[ -n "${href}" ] && printf '%s/%s' "$(dirname "${output}")" "${href}"
}

# Run the structure checks of the HTML output, and print one "name ok" or
# "name fail: reason" line for each.
structure_report() {
	python3 -I - "${output}" <<'PY'
import sys
from html.parser import HTMLParser

SECTIONING = {"article", "aside", "main", "nav", "section"}
FOCUSABLE = {"button", "input", "select", "textarea", "summary"}


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.in_body = False
        self.first_focusable = None
        self.headers = []
        self.navs = []
        self.mains = []
        self.footers = []
        self.ids = set()
        self.motifs = []
        self.title_parts = set()
        self.body_children = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        if tag == "body":
            self.in_body = True
        if self.in_body and self.first_focusable is None:
            focusable = (tag == "a" and "href" in attrs) or tag in FOCUSABLE or (
                "tabindex" in attrs and attrs["tabindex"] != "-1"
            )
            if focusable and attrs.get("type") != "hidden":
                self.first_focusable = (tag, attrs)
        ancestors = [name for name, _ in self.stack]
        if self.stack and self.stack[-1][0] == "body":
            self.body_children.append((tag, attrs))
        if tag == "header":
            self.headers.append((attrs, not SECTIONING & set(ancestors)))
        if tag == "nav":
            self.navs.append(attrs)
        if tag == "main":
            self.mains.append(attrs)
        if tag == "footer":
            self.footers.append((attrs, not SECTIONING & set(ancestors)))
        in_title = any(a.get("id") == "title-block-header" for _, a in self.stack)
        if tag == "svg" and "mc-motif" in attrs.get("class", "").split():
            self.motifs.append((attrs, self.stack[-1][1].get("id") if self.stack else None))
        if in_title:
            for name in attrs.get("class", "").split():
                self.title_parts.add(name)
            if tag == "h1":
                self.title_parts.add("h1")
            if tag == "a" and attrs.get("href", "").startswith("https://orcid.org/"):
                self.title_parts.add("orcid:" + attrs.get("aria-label", ""))
        if tag not in {"meta", "link", "img", "br", "hr", "input", "source", "path", "circle", "rect", "stop"}:
            self.stack.append((tag, attrs))

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                break


page = Page()
page.feed(open(sys.argv[1], encoding="utf-8").read())


def report(name, ok, reason):
    print(f"{name} ok" if ok else f"{name} fail: {reason}")


banner = [attrs for attrs, top in page.headers if top and attrs.get("id") == "title-block-header"]
report("landmark-header", len(banner) == 1, "one header#title-block-header outside sectioning content")
labelled = [n for n in page.navs if n.get("aria-label") or n.get("aria-labelledby")]
report("landmark-nav", len(labelled) >= 1, "a nav with aria-label or aria-labelledby")
report("landmark-main", len(page.mains) == 1 and page.mains[0].get("id") == "quarto-document-content", "one main#quarto-document-content")
page_footers = [attrs for attrs, top in page.footers if top]
report("landmark-footer", len(page_footers) == 1, "one footer outside sectioning content")
tag, attrs = page.first_focusable or ("none", {})
target = attrs.get("href", "")[1:]
report(
    "skip-link-first",
    tag == "a" and attrs.get("id") == "quarto-skip-link" and target in page.ids and target == "quarto-document-content",
    f"the first focusable element is the skip link to main, found <{tag} {attrs}>",
)
in_header = [m for m, parent in page.motifs if parent == "title-block-header"]
report("motif-in-title-block", len(in_header) == 1, "one svg.mc-motif as a child of header#title-block-header")
report("motif-aria-hidden", all(m.get("aria-hidden") == "true" for m, _ in page.motifs) and page.motifs, "every svg.mc-motif has aria-hidden=true")
for part in ["mc-kicker", "h1", "mc-title-rule", "subtitle", "mc-authors", "mc-affiliations", "mc-author-legends", "mc-meta", "mc-abstract", "mc-keywords"]:
    report(f"title-block-{part}", part in page.title_parts, f"{part} in the title block")
orcid = [p for p in page.title_parts if p.startswith("orcid:")]
report("title-block-orcid-name", any(p.startswith("orcid:ORCID 0000-") for p in orcid), "an ORCID link named 'ORCID <id>'")
PY
}

# Succeed when the structure report has an ok line for a check.
# $1 name of the check.
structure_ok() {
	grep -qxF "$1 ok" <<<"${structure}" || {
		grep -F "$1 " <<<"${structure}" | sed 's/^/# /'
		return 1
	}
}

# Succeed when both schemes of the output hold a token with the preset values.
# $1 preset. $2 token.
both_schemes() {
	local light_mode=light
	[ "$1" = terminal ] && light_mode=dark
	css_token 'body.quarto-light' "$2" "$(preset_value "$1" "${light_mode}" "$2")" &&
		css_token 'body.quarto-dark' "$2" "$(preset_value "$1" dark "$2")"
}

# Succeed when the light and dark token rules of the output are the same.
same_schemes() {
	[ "$(css_rule "${output}" 'body.quarto-light' | sed 's/^body\.quarto-light//')" = \
		"$(css_rule "${output}" 'body.quarto-dark' | sed 's/^body\.quarto-dark//')" ]
}

# Succeed when a stylesheet holds an extended regular expression.
# $1 stylesheet. $2 pattern.
css_has() {
	[ -f "$1" ] && grep -qE -- "$2" "$1"
}

# Answer the selector prefix of the rules of one preset in the compiled CSS.
# $1 preset.
preset_scope() {
	printf ':where\\(:root:has\\(meta\\[name="?mcanouil-preset"?\\]\\[content="?%s"?\\]\\)\\)' "$1"
}

# Succeed when the preset rules of the stylesheet hold a pattern.
# $1 stylesheet. $2 preset. $3 pattern after the scope.
preset_rule() {
	css_has "$1" "$(preset_scope "$2")[^{]*$3"
}

# Succeed when the motif of the output touches the edges of its view box:
# facets, ribbon and steps reach the top and the right edge; dots keep the same
# margin at the top and the right.
motif_corner() {
	python3 -I - "${output}" <<'PY'
import re
import sys

html = open(sys.argv[1], encoding="utf-8").read()
svg = re.search(r'<svg[^>]*class="mc-motif mc-motif-(\w+)"[^>]*>(.*?)</svg>', html, re.S)
if not svg:
    sys.exit("# no motif svg")
kind, body = svg.group(1), svg.group(2)
if kind == "dots":
    circles = [(float(x), float(y), float(r)) for x, y, r in re.findall(r'<circle cx="([\d.]+)" cy="([\d.]+)" r="([\d.]+)"', body)]
    right = 100 - max(x + r for x, _, r in circles)
    top = min(y - r for _, y, r in circles)
    sys.exit(0 if abs(right - top) < 0.01 else f"# dots margins differ: right {right}, top {top}")
points = []
for d in re.findall(r'<path d="([^"]+)"', body):
    numbers = [float(n) for n in re.findall(r"[\d.]+", d)]
    points += list(zip(numbers[0::2], numbers[1::2]))
for x, y, w, h in re.findall(r'<rect x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)"', body):
    points.append((float(x) + float(w), float(y)))
top = any(y == 0 for _, y in points)
right = any(x == 100 for x, _ in points)
sys.exit(0 if top and right else f"# {kind} shapes: top edge {top}, right edge {right}")
PY
}

# Answer the command of a headless Chromium browser, or nothing.
find_browser() {
	local candidate
	for candidate in "${CHROME_PATH:-}" "${QUARTO_CHROMIUM:-}" \
		"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		"/Applications/Chromium.app/Contents/MacOS/Chromium" \
		"$(command -v google-chrome || true)" "$(command -v chromium || true)" "$(command -v chromium-browser || true)"; do
		if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
			printf '%s' "${candidate}"
			return 0
		fi
	done
}

# Measure the title block and its motif in the browser, in a frame of one
# size, and print the measures as JSON. The page runs in a frame because a
# headless window is never narrower than 500 pixels.
# $1 width. $2 height.
measure() {
	local page frame dump
	page="$(dirname "${output}")/.measure-$$-page.html"
	frame="$(dirname "${output}")/.measure-$$-frame.html"
	python3 -I - "${output}" "${page}" "${frame}" "$1" "$2" <<'PY'
import os
import sys

script = """<script>
window.addEventListener("load", () => document.fonts.ready.then(() => {
  const header = document.getElementById("title-block-header");
  const motif = header && header.querySelector(":scope > svg.mc-motif");
  const out = { viewport: document.documentElement.clientWidth };
  if (header && motif) {
    const h = header.getBoundingClientRect();
    const m = motif.getBoundingClientRect();
    const style = getComputedStyle(motif);
    out.header = [h.top + window.scrollY, h.right];
    out.motif = [m.top + window.scrollY, m.right, m.width, m.height];
    out.box = [style.marginTop, style.marginRight, style.paddingTop, style.paddingRight].join(" ");
    out.overlaps = [];
    const walker = document.createTreeWalker(header, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
      const node = walker.currentNode;
      if (!node.textContent.trim() || motif.contains(node)) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      for (const r of range.getClientRects()) {
        if (r.right > m.left && r.left < m.right && r.bottom > m.top && r.top < m.bottom) {
          out.overlaps.push(node.textContent.trim().slice(0, 30));
        }
      }
    }
  }
  parent.postMessage(JSON.stringify(out), "*");
}));
</script>"""
html = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write(html.replace("</body>", script + "</body>", 1))
frame = f"""<!DOCTYPE html><html><body style="margin:0">
<iframe src="{os.path.basename(sys.argv[2])}" width="{sys.argv[4]}" height="{sys.argv[5]}" style="border:0;display:block"></iframe>
<script>window.addEventListener("message", (e) => document.body.setAttribute("data-mc-measure", e.data));</script>
</body></html>"""
open(sys.argv[3], "w", encoding="utf-8").write(frame)
PY
	dump="$("${browser}" --headless=new --disable-gpu --no-first-run --hide-scrollbars \
		--window-size=1600,1000 --virtual-time-budget=8000 --dump-dom "file://${frame}" 2>/dev/null || true)"
	rm -f "${page}" "${frame}"
	python3 -I -c '
import html, re, sys
found = re.search(r"data-mc-measure=\"([^\"]*)\"", sys.stdin.read())
print(html.unescape(found.group(1)) if found else "{}")
' <<<"${dump}"
}

# Succeed when the measures put the motif flush in the top right corner of the
# title block, the title block at the top right corner of the page, with no
# margin or padding on the motif and no text over the motif.
# $1 measures, as JSON.
flush_corner() {
	python3 -I -c '
import json, sys
m = json.loads(sys.argv[1])
if "motif" not in m:
    sys.exit("# no measures: " + sys.argv[1])
problems = []
if abs(m["motif"][0] - m["header"][0]) > 0.5: problems.append("motif top %s, block top %s" % (m["motif"][0], m["header"][0]))
if abs(m["motif"][1] - m["header"][1]) > 0.5: problems.append("motif right %s, block right %s" % (m["motif"][1], m["header"][1]))
if abs(m["header"][0]) > 0.5: problems.append("block top %s, page top 0" % m["header"][0])
if abs(m["header"][1] - m["viewport"]) > 0.5: problems.append("block right %s, page right %s" % (m["header"][1], m["viewport"]))
if m["box"] != "0px 0px 0px 0px": problems.append("motif margin and padding " + m["box"])
if m["motif"][2] <= 0: problems.append("motif has no size")
if m["overlaps"]: problems.append("text over the motif: " + ", ".join(m["overlaps"]))
for problem in problems: print("# " + problem)
sys.exit(1 if problems else 0)
' "$1"
}

# Succeed when axe-core finds nothing on the page, in light and dark, at 1440
# and 320 pixels wide (the default matrix of quarto call axe). The scan writes
# its artefacts to tests/_axe-checks, which ignores itself.
axe_clean() {
	local report status=0
	report="$(mktemp -d)"
	quarto call axe "$(dirname "${output}")" --pages "$(basename "${output}")" --settle 500 \
		--fail-on minor --quiet --report "${report}/report.md" || status=$?
	if [ "${status}" -ne 0 ] && [ -f "${report}/report.md" ]; then
		sed 's/^/# /' "${report}/report.md" | head -n 40
	fi
	rm -rf "${report}"
	return "${status}"
}

# Check the title page of one preset.
# $1 preset.
check_title() {
	local preset="$1" light_css dark_css size measures
	structure="$(structure_report)"
	light_css="$(linked_css quarto-bootstrap 0)"
	dark_css="$(linked_css quarto-bootstrap 1)"

	expect "html-schemes-${preset}" "--mc-accent-text of ${preset} in body.quarto-light and body.quarto-dark" \
		both_schemes "${preset}" accent-text
	expect "html-schemes-stylesheets-${preset}" "a light and a dark Bootstrap stylesheet" \
		test -f "${light_css}" -a -f "${dark_css}"
	if [ "${preset}" = terminal ]; then
		expect "html-terminal-dark-only-tokens" "the same tokens in body.quarto-light and body.quarto-dark" same_schemes
		expect "html-terminal-dark-only-scheme" "color-scheme: dark for terminal" \
			preset_rule "${light_css}" terminal '\{color-scheme:dark'
		expect "html-terminal-dark-only-toggle" "no scheme toggle for terminal" \
			preset_rule "${light_css}" terminal '\.quarto-color-scheme-toggle[^{]*\{display:none'
	fi

	for name in landmark-header landmark-nav landmark-main landmark-footer skip-link-first; do
		expect "html-${name}-${preset}" "${name}, see the line above" structure_ok "${name}"
	done
	expect "html-skip-link-style-${preset}" "a visible focus style for the skip link" \
		css_has "${light_css}" '#quarto-skip-link:focus\{[^}]*var\(--mc-link\)'
	expect "html-focus-ring-${preset}" "focus rings in the link colour" \
		css_has "${light_css}" 'focus-visible[^{]*\{[^}]*outline:[^;}]*var\(--mc-link\)'

	for name in title-block-mc-kicker title-block-h1 title-block-mc-title-rule title-block-subtitle title-block-mc-authors \
		title-block-mc-affiliations title-block-mc-author-legends title-block-mc-meta title-block-mc-abstract \
		title-block-mc-keywords title-block-orcid-name; do
		expect "html-${name}-${preset}" "${name}, see the line above" structure_ok "${name}"
	done
	expect "html-kicker-default-${preset}" "the report kicker" has "${output}" '<p class="mc-kicker">Report</p>'

	expect "html-motif-in-title-block-${preset}" "the motif in the title block" structure_ok motif-in-title-block
	expect "html-motif-hidden-aria-${preset}" "aria-hidden on the motif" structure_ok motif-aria-hidden
	expect "html-motif-hidden-forced-colors-${preset}" "the motif hidden under forced colours" \
		css_has "${light_css}" '@media ?\(forced-colors: ?active\) ?\{[^@]*\.mc-motif[^{]*\{display:none'
	expect "html-motif-hidden-reduced-motion-${preset}" "a prefers-reduced-motion guard" \
		css_has "${light_css}" '@media ?\(prefers-reduced-motion: ?reduce\) ?\{[^{]*\.mc-motif'
	expect "html-motif-corner-${preset}" "the motif shapes at the corner of the view box" motif_corner

	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	for size in 1440,900 768,1024 320,568; do
		measures="$(measure "${size%,*}" "${size#*,}")"
		expect "html-motif-flush-${preset}-${size%,*}" "the motif flush in the top right corner, no text over it" \
			flush_corner "${measures}"
	done

	expect "html-fonts-local-${preset}" "local @font-face files and no font service" html_fonts_local
	expect "html-axe-${preset}" "no axe-core finding in light and dark, at 1440 and 320 pixels" axe_clean

	expect "html-preset-style-${preset}" "rules scoped to the ${preset} preset" preset_rule "${light_css}" "${preset}" '\.mc-kicker'
	case "${preset}" in
	gold)
		expect "html-gold-kicker-small-caps" "a small-caps kicker" preset_rule "${light_css}" gold '\.mc-kicker\{[^}]*small-caps'
		expect "html-gold-h2-gilded" "a gilded rule under H2" preset_rule "${light_css}" gold 'h2::?after\{[^}]*linear-gradient'
		;;
	mono)
		expect "html-mono-kicker-inverted" "an inverted label kicker" preset_rule "${light_css}" mono '\.mc-kicker\{[^}]*background(-color)?:var\(--mc-ink\)'
		expect "html-mono-h2-top-rule" "uppercase H2 under a top rule" preset_rule "${light_css}" mono 'h2\{[^}]*border-top[^}]*text-transform:uppercase'
		;;
	quarto)
		expect "html-quarto-kicker-pill" "a pill kicker" preset_rule "${light_css}" quarto '\.mc-kicker\{[^}]*border-radius:999px'
		expect "html-quarto-h2-bar" "an accent bar beside H2" preset_rule "${light_css}" quarto 'h2::?before\{[^}]*var\(--mc-accent\)'
		;;
	terminal)
		expect "html-terminal-prompt-hidden" "a \$ prompt with empty alternative text" preset_rule "${light_css}" terminal '\.title::?before\{[^}]*content:"\$ ?"/""'
		expect "html-terminal-kicker-brackets" "[ ] around the kicker, not read" preset_rule "${light_css}" terminal '\.mc-kicker::?before\{[^}]*content:"\[ ?"/""'
		expect "html-terminal-h2-hashes" "## before H2, not read" preset_rule "${light_css}" terminal 'h2::?before\{[^}]*content:"## ?"/""'
		;;
	esac
}

# Check that a document in a subdirectory of a project finds the fonts and the motif.
check_subdir() {
	structure="$(structure_report)"
	expect "subdir-assets-html-fonts" "local @font-face files beside the output" html_fonts_local
	expect "subdir-assets-html-motif" "the motif in the title block" structure_ok motif-in-title-block
}

structure=""
browser=""
case "${1:-}" in
title) check_title "${2:?title needs a preset}" ;;
subdir) check_subdir ;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
