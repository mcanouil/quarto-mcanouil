#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, ext_dir and tests_dir are set by lib.sh
set -euo pipefail

# Check hook: the base of the HTML format, from the rendered page.
#
# Usage: html.sh title <preset>
#        html.sh components <preset>
#        html.sh subdir
#
# The title case checks the schemes, the landmarks, the skip link, the title
# block and its corner motif, the local fonts and the preset style rules of one
# preset, and runs axe-core on the page with quarto call axe. The components
# case checks the callouts, tabsets, code, tables and block quotes of one
# preset: labels, the tab pattern, colours in both schemes, decoration in
# forced colours, and axe-core. The motif
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

# Answer the command of a headless Chromium browser, or nothing: CHROME_PATH,
# QUARTO_CHROMIUM, an installed Brave, Chrome or Chromium, then the newest
# Chromium that Playwright downloaded (macOS and Linux caches).
find_browser() {
	local candidate
	for candidate in "${CHROME_PATH:-}" "${QUARTO_CHROMIUM:-}" \
		"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
		"/Applications/Chromium.app/Contents/MacOS/Chromium" \
		"$(command -v google-chrome || true)" "$(command -v chromium || true)" "$(command -v chromium-browser || true)" \
		"$(find "${HOME}/Library/Caches/ms-playwright" "${HOME}/.cache/ms-playwright" -maxdepth 6 -type f \
			\( -path '*/chromium-*/Contents/MacOS/*' -o -path '*/chromium-*/chrome-linux*/chrome' \) 2>/dev/null | sort | tail -n 1)"; do
		if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
			printf '%s' "${candidate}"
			return 0
		fi
	done
}

# Measure the page in the browser, in a frame of one size, with one of the
# measure scripts (html-measure-<kind>.js), and print the measures as JSON. The
# page runs in a frame because a headless window is never narrower than 500
# pixels. With "forced", the page uses copies of its stylesheets in which the
# forced-colors media query always applies, so the computed styles are those
# of forced colours mode. With "dark", the browser prefers the dark scheme, so
# Quarto loads the dark stylesheets; otherwise it prefers the light scheme.
# $1 width. $2 height. $3 "forced", "dark" or nothing. $4 kind: title (default)
# or components.
measure() {
	local page frame dump scheme=light
	page="$(dirname "${output}")/.measure-$$-page.html"
	frame="$(dirname "${output}")/.measure-$$-frame.html"
	[ "${3:-}" = dark ] && scheme=dark
	python3 -I - "${output}" "${page}" "${frame}" "$1" "$2" "${3:-}" "${tests_dir}/_checks/html-measure-${4:-title}.js" <<'PY'
import os
import re
import sys

source, page, frame, width, height, mode, script_file = sys.argv[1:8]
script = "<script>" + open(script_file, encoding="utf-8").read() + "</script>"
html = open(source, encoding="utf-8").read()
if mode == "forced":
    def forced_copy(match):
        href = match.group(1)
        path = os.path.join(os.path.dirname(source), href)
        if not href.endswith(".css") or not os.path.isfile(path):
            return match.group(0)
        css = open(path, encoding="utf-8").read()
        css = re.sub(r"@media ?\(forced-colors: ?active\)", "@media all", css)
        copy = os.path.join(os.path.dirname(path), ".forced-" + os.path.basename(path))
        open(copy, "w", encoding="utf-8").write(css)
        return match.group(0).replace(href, os.path.join(os.path.dirname(href), ".forced-" + os.path.basename(href)))
    html = re.sub(r'<link\b[^>]*href="([^"]+)"[^>]*>', forced_copy, html)
open(page, "w", encoding="utf-8").write(html.replace("</body>", script + "</body>", 1))
open(frame, "w", encoding="utf-8").write(f"""<!DOCTYPE html><html><body style="margin:0">
<iframe src="{os.path.basename(page)}" width="{width}" height="{height}" style="border:0;display:block"></iframe>
<script>window.addEventListener("message", (e) => document.body.setAttribute("data-mc-measure", e.data));</script>
</body></html>""")
PY
	dump="$("${browser}" --headless=new --disable-gpu --no-first-run --hide-scrollbars \
		"--blink-settings=preferredColorScheme=$([ "${scheme}" = dark ] && echo 0 || echo 1)" \
		--window-size=1600,1000 --virtual-time-budget=8000 --dump-dom "file://${frame}" 2>/dev/null || true)"
	rm -f "${page}" "${frame}"
	find "$(dirname "${output}")" -name '.forced-*.css' -delete
	python3 -I -c '
import html, re, sys
found = re.search(r"data-mc-measure=\"([^\"]*)\"", sys.stdin.read())
print(html.unescape(found.group(1)) if found else "{}")
' <<<"${dump}"
}

# Succeed when the measures put the motif flush in the top right corner of the
# title block, the title block at the top right corner of the page, with no
# margin or padding on the motif, no text over the motif or the scheme toggle,
# and the scheme toggle clear of the motif.
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
if m["overlaps"]: problems.append("text over a decoration or control: " + ", ".join(m["overlaps"]))
for problem in problems: print("# " + problem)
sys.exit(1 if problems else 0)
' "$1"
}

# Succeed when the scheme toggle, when it shows, does not overlap the motif.
# $1 measures, as JSON.
toggle_clear() {
	python3 -I -c '
import json, sys
m = json.loads(sys.argv[1])
if "motif" not in m:
    sys.exit("# no measures: " + sys.argv[1])
if m.get("toggleOverMotif"):
    sys.exit("# toggle %s over the motif %s" % (m["toggle"], m["motif"]))
' "$1"
}

# Succeed when every decoration is hidden in forced colours mode.
# $1 measures in forced colours mode, as JSON.
decorations_hidden() {
	python3 -I -c '
import json, sys
shown = {k: v for k, v in json.loads(sys.argv[1]).get("decorations", {"measures": "none"}).items() if v != "none"}
for name, display in shown.items(): print("# %s display %s" % (name, display))
sys.exit(1 if shown else 0)
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
		expect "html-motif-flush-${preset}-${size%,*}" "the motif flush in the top right corner, no text over it or the toggle" \
			flush_corner "${measures}"
		expect "html-toggle-clear-${preset}-${size%,*}" "the scheme toggle clear of the motif" toggle_clear "${measures}"
	done
	measures="$(measure 1440 900 forced)"
	expect "html-motif-hidden-forced-colors-${preset}" "motif, title rule, H2 and title decorations hidden in forced colours" \
		decorations_hidden "${measures}"

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

# Run the structure checks of the components of the HTML output: the ARIA tab
# pattern of each tabset, and the block quotes with their attribution. Print
# one "name ok" or "name fail: reason" line for each.
components_report() {
	python3 -I - "${output}" <<'PY'
import sys
from html.parser import HTMLParser

VOID = {"br", "img", "hr", "input", "meta", "link", "source", "wbr"}


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tablists = []
        self.tabs = []
        self.panels = set()
        self.quotes = []
        self.depth = []
        self.footer = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        role = attrs.get("role")
        if role == "tablist":
            self.tablists.append(attrs)
        if role == "tab":
            self.tabs.append(attrs)
        if role == "tabpanel" and attrs.get("id"):
            self.panels.add(attrs["id"])
        if tag == "blockquote":
            self.quotes.append({"attrs": attrs, "children": [], "footer": None})
            self.depth.append(0)
        elif self.depth and tag not in VOID:
            if self.depth[-1] == 0:
                self.quotes[-1]["children"].append(tag)
                if tag == "footer":
                    self.quotes[-1]["footer"] = ""
                    self.footer = self.quotes[-1]
            self.depth[-1] += 1

    def handle_endtag(self, tag):
        if tag == "blockquote" and self.depth:
            self.depth.pop()
        elif self.depth and tag not in VOID:
            self.depth[-1] -= 1
            if tag == "footer":
                self.footer = None

    def handle_data(self, data):
        if self.footer is not None:
            self.footer["footer"] += data


page = Page()
page.feed(open(sys.argv[1], encoding="utf-8").read())


def report(name, ok, reason):
    print(f"{name} ok" if ok else f"{name} fail: {reason}")


selected = [t for t in page.tabs if t.get("aria-selected") == "true"]
controls = [t.get("aria-controls") for t in page.tabs]
report(
    "tabset-aria",
    len(page.tablists) >= 1
    and len(page.tabs) >= 2
    and len(selected) == len(page.tablists)
    and all(t.get("aria-selected") in {"true", "false"} for t in page.tabs)
    and all(c in page.panels for c in controls),
    "role=tablist, role=tab with aria-selected (one true per list) and aria-controls to a role=tabpanel; "
    f"found {len(page.tablists)} lists, {len(page.tabs)} tabs, {len(selected)} selected, "
    f"controls {controls}, panels {sorted(page.panels)}",
)
attributed = [q for q in page.quotes if q["footer"] is not None]
report(
    "quote-attribution",
    len(attributed) == 1
    and attributed[0]["children"][-1] == "footer"
    and attributed[0]["footer"].strip() == "Mickaël Canouil, 2026",
    "one blockquote whose last child is a footer with the attribution, dash dropped; found "
    + repr([(q["children"], q["footer"]) for q in page.quotes]),
)
report(
    "quote-label",
    len(page.quotes) == 2 and all(q["attrs"].get("data-mc-label") for q in page.quotes),
    "a data-mc-label on every block quote",
)
PY
}

# Succeed when the measures pass a test. The test is a Python expression over
# m, the measures; the reason, a Python expression too, is printed when the
# test fails.
# $1 measures, as JSON. $2 test. $3 reason.
measured() {
	python3 -I -c '
import json, sys
m = json.loads(sys.argv[1])
if not m:
    sys.exit("# no measures")
if not eval(sys.argv[2]):
    print("# " + str(eval(sys.argv[3])))
    sys.exit(1)
' "$1" "$2" "$3"
}

# Succeed when every component text has a contrast of 4.5:1 or more with the
# colour behind it, and every background belongs to the scheme: dark
# (relative luminance below 0.2) or light (above 0.4). An active tab may be
# inverted, so only its contrast counts.
# $1 measures, as JSON. $2 expected scheme: light or dark.
component_colours() {
	python3 -I -c '
import json, sys
m = json.loads(sys.argv[1])
scheme = sys.argv[2]
if not m.get("colours"):
    sys.exit("# no measures")
problems = []
seen = set()
for c in m["colours"]:
    dark = c["bgLuminance"] < 0.2
    light = c["bgLuminance"] > 0.4
    inverted = c["label"] == "active tab"
    wrong = c["ratio"] < 4.5 or (not inverted and ((scheme == "dark" and not dark) or (scheme == "light" and not light)))
    key = (c["label"], c["fg"], c["bg"])
    if wrong and key not in seen:
        seen.add(key)
        problems.append("%s %r: %s on %s = %.2f" % (c["label"], c["text"], c["fg"], c["bg"], c["ratio"]))
for problem in problems[:12]:
    print("# " + problem)
sys.exit(1 if problems else 0)
' "$1" "$2"
}

# Succeed when no stylesheet of the extension uses !important, except on a
# line whose comment names an upstream Quarto issue (quarto-cli#<number>).
# Comment lines do not count.
no_important() {
	local found
	found="$(grep -rn '!important' "${ext_dir}/html" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' |
		grep -v 'quarto-cli#[0-9]' || true)"
	[ -z "${found}" ] || {
		printf '# %s\n' "${found}"
		return 1
	}
}

# Check the components page of one preset.
# $1 preset.
check_components() {
	local preset="$1" light_css scheme expected size measures
	structure="$(components_report)"
	light_css="$(linked_css quarto-bootstrap 0)"

	expect "html-tabset-aria-${preset}" "the ARIA tab pattern, see the line above" structure_ok tabset-aria
	expect "html-quote-attribution-${preset}" "the attribution in a footer, see the line above" structure_ok quote-attribution
	expect "html-quote-label-${preset}" "the label of the quote decoration on every quote" structure_ok quote-label
	expect "html-no-important-${preset}" "no !important in the extension stylesheets without an upstream issue" no_important

	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	measures="$(measure 1440 900 "" components)"
	expect "html-callout-label-text-${preset}" "a visible text title on each of the five callouts" \
		measured "${measures}" 'len(m["callouts"]) == 5 and all(c["title"] for c in m["callouts"])' 'm["callouts"]'
	expect "html-callout-icon-decorative-${preset}" "callout icons with no text and silent generated content" \
		measured "${measures}" 'm["icons"] and all(not i["text"] and i["silent"] for i in m["icons"])' 'm["icons"]'
	for size in 1440,900 320,568; do
		measures="$(measure "${size%,*}" "${size#*,}" "" components)"
		expect "html-callout-motif-${preset}-${size%,*}" "a corner motif on each callout, with no text over it" \
			measured "${measures}" 'm["motifs"] == 5 and not m["motifOverlaps"]' '(m["motifs"], m["motifOverlaps"])'
	done
	for scheme in light dark; do
		expected="${scheme}"
		[ "${preset}" = terminal ] && expected=dark
		measures="$(measure 1440 900 "$([ "${scheme}" = dark ] && echo dark || true)" components)"
		expect "html-component-scheme-${preset}-${scheme}" "the ${scheme} stylesheet when the browser prefers ${scheme}" \
			measured "${measures}" "m['scheme'] == '${scheme}' or '${preset}' == 'terminal'" 'm["scheme"]'
		expect "html-component-colours-${preset}-${scheme}" "component text at 4.5:1 or more on ${expected} backgrounds" \
			component_colours "${measures}" "${expected}"
	done
	measures="$(measure 1440 900 forced components)"
	expect "html-component-decoration-forced-colors-${preset}" "component decorations hidden in forced colours" \
		decorations_hidden "${measures}"
	expect "html-tab-active-forced-colors-${preset}" "the active tab marked by more than colour in forced colours" \
		measured "${measures}" '"underline" in m["activeTab"]["decoration"] or m["activeTab"]["border"].startswith("solid")' 'm["activeTab"]'

	expect "html-axe-components-${preset}" "no axe-core finding in light and dark, at 1440 and 320 pixels" axe_clean

	expect "html-components-style-${preset}" "callout rules scoped to the ${preset} preset" \
		preset_rule "${light_css}" "${preset}" '\.callout'
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
components) check_components "${2:?components needs a preset}" ;;
subdir) check_subdir ;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
