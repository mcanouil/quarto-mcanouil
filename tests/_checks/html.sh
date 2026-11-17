#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, ext_dir and tests_dir are set by lib.sh
set -euo pipefail

# Check hook: the base of the HTML format, from the rendered page.
#
# Usage: html.sh title <preset>
#        html.sh components <preset>
#        html.sh toc <preset>
#        html.sh memo <note|minutes|agenda|brief|missing> <preset>
#        html.sh book
#        html.sh full
#        html.sh overlap
#        html.sh subdir
#        html.sh measure <width> <height> [mode] [kind]   (prints the measures)
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
# of forced colours mode; "print" and "reduced" do the same for the print and
# the prefers-reduced-motion queries. With "rtl", the page is right to left.
# With "dark", the browser prefers the dark scheme, so Quarto loads the dark
# stylesheets; otherwise it prefers the light scheme. The measure script reads
# the mode from window.mcMode ("open" opens the sidebar drawer).
# $1 width. $2 height. $3 "forced", "print", "reduced", "rtl", "open", "dark"
# or nothing. $4 kind: title (default), components or nav.
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
QUERIES = {
    "forced": r"@media ?\(forced-colors: ?active\)",
    "print": r"@media print",
    "reduced": r"@media ?\(prefers-reduced-motion: ?reduce\)",
}
if mode in QUERIES:
    def media_copy(match):
        href = match.group(1)
        path = os.path.join(os.path.dirname(source), href)
        if not href.endswith(".css") or not os.path.isfile(path):
            return match.group(0)
        css = open(path, encoding="utf-8").read()
        css = re.sub(QUERIES[mode], "@media all", css)
        copy = os.path.join(os.path.dirname(path), ".forced-" + os.path.basename(path))
        open(copy, "w", encoding="utf-8").write(css)
        open(page + ".copies", "a", encoding="utf-8").write(copy + "\n")
        return match.group(0).replace(href, os.path.join(os.path.dirname(href), ".forced-" + os.path.basename(href)))
    html = re.sub(r'<link\b[^>]*href="([^"]+)"[^>]*>', media_copy, html)
if mode == "rtl":
    html = re.sub(r"<html\b", '<html dir="rtl"', html, count=1)
script = f"<script>window.mcMode = {mode!r};</script>" + script
open(page, "w", encoding="utf-8").write(html.replace("</body>", script + "</body>", 1))
open(frame, "w", encoding="utf-8").write(f"""<!DOCTYPE html><html><body style="margin:0">
<iframe src="{os.path.basename(page)}" width="{width}" height="{height}" style="border:0;display:block"></iframe>
<script>window.addEventListener("message", (e) => document.body.setAttribute("data-mc-measure", e.data));</script>
</body></html>""")
PY
	dump="$("${browser}" --headless=new --disable-gpu --no-first-run --hide-scrollbars \
		"--blink-settings=preferredColorScheme=$([ "${scheme}" = dark ] && echo 0 || echo 1)" \
		--window-size=1600,1000 --virtual-time-budget=8000 --run-all-compositor-stages-before-draw \
		--dump-dom "file://${frame}" 2>/dev/null || true)"
	if [ -f "${page}.copies" ]; then
		while IFS= read -r copy; do rm -f "${copy}"; done <"${page}.copies"
	fi
	rm -f "${page}" "${frame}" "${page}.copies"
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
# and 320 pixels wide (the default matrix of quarto call axe), or at other
# sizes. The scan writes its artefacts to _axe-checks in the project of the
# page, which ignores itself.
# $1 page globs, relative to the site directory (default: the output page).
# $2 viewports, as WxH separated by commas (default: 1440x900,320x568).
# $3 site directory (default: the directory of the output).
axe_clean() {
	local report status=0
	report="$(mktemp -d)"
	quarto call axe "${3:-$(dirname "${output}")}" --pages "${1:-$(basename "${output}")}" --settle 500 \
		--viewports "${2:-1440x900,320x568}" --fail-on minor --quiet --report "${report}/report.md" || status=$?
	if [ "${status}" -ne 0 ] && [ -f "${report}/report.md" ]; then
		sed 's/^/# /' "${report}/report.md" | head -n 40
	fi
	rm -rf "${report}"
	return "${status}"
}

# Report a check that waits for an upstream fix as a TAP TODO, which does
# not fail the hook. Once Quarto fixes the defect the check passes, and it
# then fails the hook, so the TODO is removed and the check kept.
# $1 name. $2 upstream issue. The rest is the command.
expect_todo() {
	local name="$1" issue="$2"
	shift 2
	if "$@"; then
		tap_not_ok "${name}" "a failure until ${issue} is fixed; it passes now, so remove the TODO (fixed upstream)"
	else
		tap_n=$((tap_n + 1))
		printf 'not ok %d - %s # TODO %s\n' "${tap_n}" "${name}" "${issue}"
	fi
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
# pattern of each tabset, and the block quotes (figure.mc-quote) with their
# attribution as the caption. Print
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
        self.caption = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        role = attrs.get("role")
        if role == "tablist":
            self.tablists.append(attrs)
        if role == "tab":
            self.tabs.append(attrs)
        if role == "tabpanel" and attrs.get("id"):
            self.panels.add(attrs["id"])
        if tag == "figure" and "mc-quote" in attrs.get("class", "").split():
            self.quotes.append({"attrs": attrs, "children": [], "caption": None})
            self.depth.append(0)
        elif self.depth and tag not in VOID:
            if self.depth[-1] == 0:
                self.quotes[-1]["children"].append(tag)
                if tag == "figcaption":
                    self.quotes[-1]["caption"] = ""
                    self.caption = self.quotes[-1]
            self.depth[-1] += 1

    def handle_endtag(self, tag):
        if self.depth and self.depth[-1] == 0 and tag == "figure":
            self.depth.pop()
        elif self.depth and tag not in VOID:
            self.depth[-1] -= 1
            if tag == "figcaption":
                self.caption = None

    def handle_data(self, data):
        if self.caption is not None:
            self.caption["caption"] += data


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
attributed = [q for q in page.quotes if q["caption"] is not None]
report(
    "quote-attribution",
    len(page.quotes) == 2
    and all(q["children"][0] == "blockquote" for q in page.quotes)
    and len(attributed) == 1
    and attributed[0]["children"] == ["blockquote", "figcaption"]
    and attributed[0]["caption"].strip() == "Mickaël Canouil, 2026",
    "two figure.mc-quote, each with a blockquote, one with the attribution as its figcaption, dash dropped; found "
    + repr([(q["children"], q["caption"]) for q in page.quotes]),
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
	expect "html-quote-attribution-${preset}" "the attribution as the caption of the quote figure, see the line above" structure_ok quote-attribution
	expect "html-quote-label-${preset}" "the label of the quote decoration on every quote" structure_ok quote-label
	expect "html-no-important-${preset}" "no !important in the extension stylesheets without an upstream issue" no_important

	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	measures="$(measure 1440 900 "" components)"
	expect "html-callout-label-text-${preset}" "a visible text title on each of the six callouts" \
		measured "${measures}" 'len(m["callouts"]) == 6 and all(c["title"] for c in m["callouts"])' 'm["callouts"]'
	expect "html-callout-type-shown-${preset}" "the type of a callout with a custom title shown as text or glyph, not colour alone" \
		measured "${measures}" 'sum(c["custom"] for c in m["callouts"]) == 2 and all(c["typeShown"] for c in m["callouts"])' 'm["callouts"]'
	expect "html-tab-active-cue-${preset}" "the active tab told from the others by more than colour" \
		measured "${measures}" 'm["activeCues"]' 'm["activeCues"]'
	expect "html-callout-icon-decorative-${preset}" "callout icons with no text and silent generated content" \
		measured "${measures}" 'm["icons"] and all(not i["text"] and i["silent"] for i in m["icons"])' 'm["icons"]'
	for size in 1440,900 320,568; do
		measures="$(measure "${size%,*}" "${size#*,}" "" components)"
		expect "html-callout-motif-${preset}-${size%,*}" "a corner motif on each callout, with no text over it" \
			measured "${measures}" 'm["motifs"] == 6 and not m["motifOverlaps"]' '(m["motifs"], m["motifOverlaps"])'
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

# Succeed when the contents has three levels, each indented from the start
# edge more than the level above (left to right, or right to left).
# $1 measures, as JSON.
toc_levels() {
	measured "$1" '(lambda d: len(d) >= 3 and all(min(d[k]) > max(d[j]) for j, k in zip(sorted(d), sorted(d)[1:])))({e["depth"]: [x["indent"] for x in m["toc"]["entries"] if x["depth"] == e["depth"]] for e in m["toc"]["entries"]})' \
		'[(e["depth"], e["indent"], e["text"][:16]) for e in m["toc"]["entries"]]'
}

# Succeed when each absolute decoration of the contents sits on the other
# side in a right-to-left page, and its clip path, when it has one, changes.
# $1 measures of the left-to-right page. $2 measures of the right-to-left page.
mirrored() {
	python3 -I -c '
import json, sys
ltr = json.loads(sys.argv[1])["toc"]["decorations"]
rtl = json.loads(sys.argv[2])["toc"]["decorations"]
problems = []
for name, a in ltr.items():
    b = rtl.get(name)
    end = lambda d: float(d["right"].rstrip("px")) < float(d["left"].rstrip("px"))
    if not b or end(a) == end(b) or (a["clip"] != "none" and a["clip"] == b["clip"]):
        problems.append("%s: %s, then %s" % (name, a, b))
for p in problems: print("# " + p)
sys.exit(1 if problems else 0)
' "$1" "$2"
}

# The Python test of a current entry or page that is told from the others by
# more than colour.
NON_COLOUR_CUE='{"weight", "decoration", "shadow", "outline", "border", "before", "after"}'

# Succeed when the pill and the sheet colours of a narrow screen come from the
# tokens of the scheme: the pill on the card or the paper, and text at 4.5:1.
# $1 measures, as JSON. $2 preset. $3 scheme of the tokens: light or dark.
pill_tokens() {
	measured "$1" "m.get('pill') and m['pill']['colour']['bg'] in ('$(preset_value "$2" "$3" card)', '$(preset_value "$2" "$3" paper)') and m['pill']['colour']['ratio'] >= 4.5" 'm.get("pill")'
}

# Check the contents of one preset, in every state of the spec: label, three
# numbered levels, long titles, current entry, hover and focus, actions,
# sticky with its own scroll, print, forced colours, reduced motion, right to
# left, and the pill and sheet of narrow screens.
# $1 preset.
check_toc() {
	local preset="$1" light_css scheme expected measures ltr
	structure="$(structure_report)"
	light_css="$(linked_css quarto-bootstrap 0)"
	expect "html-toc-nav-label-${preset}" "a labelled nav for the contents" structure_ok landmark-nav

	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	measures="$(measure 1440 900 "" nav)"
	expect "html-toc-label-${preset}" "a visible contents label" measured "${measures}" 'm["toc"]["label"]' 'm["toc"]'
	expect "html-toc-levels-${preset}" "three levels, each indented from the one above" toc_levels "${measures}"
	expect "html-toc-numbered-${preset}" "numbered entries" \
		measured "${measures}" 'all(e["text"][:1].isdigit() for e in m["toc"]["entries"])' '[e["text"] for e in m["toc"]["entries"]]'
	expect "html-toc-wrap-${preset}" "long titles wrap, and nothing overflows the contents" \
		measured "${measures}" 'any(e["lines"] >= 2 for e in m["toc"]["entries"]) and not any(e["overflow"] for e in m["toc"]["entries"] if e["shown"]) and not m["toc"]["overflowX"]' \
		'([(e["text"], e["lines"], e["overflow"]) for e in m["toc"]["entries"]], m["toc"]["overflowX"])'
	expect_todo "html-toc-aria-current-${preset}" "quarto-cli: active contents entry has no aria-current (draft)" \
		measured "${measures}" 'm["toc"]["current"]["ariaCurrent"] == "location"' 'm["toc"]["current"]'
	expect "html-toc-current-cue-${preset}" "the current entry told from the others by more than colour" \
		measured "${measures}" "set(m['toc']['current']['cues']) & ${NON_COLOUR_CUE}" 'm["toc"]["current"]'
	expect "html-toc-focus-ring-${preset}" "a solid focus ring of 2 pixels or more, at 3:1 or more on the contents" \
		measured "${measures}" 'm["toc"]["ring"]["focused"] and m["toc"]["ring"]["style"] == "solid" and m["toc"]["ring"]["width"] >= 2 and m["toc"]["ring"]["ratio"] >= 3' 'm["toc"]["ring"]'
	expect "html-toc-sticky-${preset}" "a sticky contents with its own scroll" \
		measured "${measures}" 'm["toc"]["position"] == "sticky" and m["toc"]["overflowY"] in ("auto", "scroll") and m["toc"]["maxHeight"] != "none"' 'm["toc"]'
	expect "html-toc-actions-${preset}" "the actions row: edit, source and issue" measured "${measures}" 'm["toc"]["actions"] == 3' 'm["toc"]["actions"]'
	for scheme in light dark; do
		expected="${scheme}"
		[ "${preset}" = terminal ] && expected=dark
		measures="$(measure 1440 900 "$([ "${scheme}" = dark ] && echo dark || true)" nav)"
		expect "html-toc-colours-${preset}-${scheme}" "contents text at 4.5:1 or more on ${expected} backgrounds" \
			component_colours "${measures}" "${expected}"
	done
	measures="$(measure 1440 900 forced nav)"
	expect "html-toc-current-forced-colors-${preset}" "a visible mark of the current entry in forced colours" \
		measured "${measures}" 'any(v for k, v in m["toc"]["current"]["forced"].items() if k != "weight")' 'm["toc"]["current"]'
	measures="$(measure 1440 900 print nav)"
	expect "html-toc-print-hidden-${preset}" "no contents in print" measured "${measures}" '"none" in m["toc"]["printDisplay"]' 'm["toc"]["printDisplay"]'
	measures="$(measure 1440 900 reduced nav)"
	expect "html-toc-reduced-motion-${preset}" "no transition under reduced motion" measured "${measures}" 'not any(m["toc"]["motion"])' 'm["toc"]["motion"]'
	ltr="$(measure 1440 900 "" nav)"
	measures="$(measure 1440 900 rtl nav)"
	expect "html-toc-rtl-${preset}" "indents from the right edge in a right-to-left page" toc_levels "${measures}"
	expect "html-toc-rtl-decoration-${preset}" "decorations of the contents on the mirrored side in a right-to-left page" \
		mirrored "${ltr}" "${measures}"

	measures="$(measure 360 640 "" nav)"
	expect "html-toc-pill-${preset}" "one pill of 44 pixels or more on a narrow screen" \
		measured "${measures}" 'm.get("pill") and m["pill"]["height"] >= 44 and len(m["pills"]) == 1' '(m.get("pill"), m["pills"])'
	expect_todo "html-toc-pill-current-section-${preset}" "mobile-toc: the pill shows the current section (spec 9.1)" \
		measured "${measures}" 'm.get("pill") and m["toc"]["current"] and m["toc"]["current"]["text"].split(" ", 1)[-1][:12] in m["pill"]["label"]' '(m.get("pill"), m["toc"]["current"])'
	expected=light
	[ "${preset}" = terminal ] && expected=dark
	expect "html-toc-pill-tokens-${preset}" "the pill on the card or paper token, text at 4.5:1" pill_tokens "${measures}" "${preset}" "${expected}"
	expect "html-toc-sheet-${preset}" "a bottom sheet of about 70 percent, a close button, text at 4.5:1, the current entry marked" \
		measured "${measures}" 'm.get("sheet") and m["sheet"]["heightShare"] <= 0.75 and m["sheet"]["close"] and all(c["ratio"] >= 4.5 for c in m["sheet"]["colours"]) and m["sheet"]["current"] and m["sheet"]["current"]["ariaCurrent"] == "location"' 'm.get("sheet")'

	expect "html-axe-toc-${preset}" "no axe-core finding in light and dark, at 1440, 768 and 320 pixels" \
		axe_clean "" 1440x900,768x1024,320x568
	expect "html-toc-style-${preset}" "contents rules scoped to the ${preset} preset" preset_rule "${light_css}" "${preset}" '#TOC'
}

# Succeed when a chapter page of a full report shows the chapter header: the
# kicker, and the "In this chapter" list with one link for each section.
# $1 measures, as JSON. $2 kicker. $3 Python list of the expected link texts.
chapter_header() {
	measured "$1" "m.get('chapter') and m['chapter']['label'] == 'In this chapter' and m['chapterNames'] == ['In this chapter'] and m['chapter']['kicker'] == '$2' and m['chapter']['links'] == $3 and all(c['ratio'] >= 4.5 for c in m['chapter']['colours'])" '(m.get("chapterNames"), m.get("chapter"))'
}

# Check the HTML render of the test book: the sidebar in every state of the
# spec, the book chrome, and the chapter header of the full layout.
check_book() {
	local site page light_css scheme expected measures
	site="$(dirname "${output}")"
	page="${site}/sections/01-design.html"
	light_css="$(linked_css quarto-bootstrap 0)"

	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	measures="$(output="${page}" measure 1440 900 "" nav)"
	expect "html-book-sidebar-buttons-expanded" "part headers as buttons with aria-expanded and aria-controls" \
		measured "${measures}" 'm["sidebar"]["toggles"] and all(t["tag"] == "BUTTON" and t["expanded"] in ("true", "false") and t["target"] for t in m["sidebar"]["toggles"])' 'm["sidebar"]["toggles"]'
	expect "html-book-sidebar-expand-marker" "a plus and minus or chevron marker on each part header" \
		measured "${measures}" 'all(t["marker"] not in ("none", "normal", "") for t in m["sidebar"]["toggles"])' 'm["sidebar"]["toggles"]'
	expect_todo "html-book-sidebar-aria-current" "quarto-cli#15190" \
		measured "${measures}" 'm["sidebar"]["current"]["ariaCurrent"] == "page"' 'm["sidebar"]["current"]'
	expect "html-book-sidebar-current-cue" "the current page told from the others by more than colour" \
		measured "${measures}" "set(m['sidebar']['current']['cues']) & ${NON_COLOUR_CUE}" 'm["sidebar"]["current"]'
	expect "html-book-sidebar-focus-ring" "a solid focus ring of 2 pixels or more, at 3:1 or more on the sidebar" \
		measured "${measures}" 'm["sidebar"]["ring"]["focused"] and m["sidebar"]["ring"]["style"] == "solid" and m["sidebar"]["ring"]["width"] >= 2 and m["sidebar"]["ring"]["ratio"] >= 3' 'm["sidebar"]["ring"]'
	expect "html-full-chapter-header-book" "the chapter kicker and the In this chapter list of the chapter page" \
		chapter_header "${measures}" Chapter '["1.1 Objectives", "1.2 Overall design", "1.2.1 Study periods", "1.3 Selection of the study population"]'
	for scheme in light dark; do
		expected="${scheme}"
		has "${page}" 'name="mcanouil-preset" content="terminal"' && expected=dark
		measures="$(output="${page}" measure 1440 900 "$([ "${scheme}" = dark ] && echo dark || true)" nav)"
		expect "html-book-sidebar-colours-${scheme}" "sidebar and contents text at 4.5:1 or more on ${expected} backgrounds" \
			component_colours "$(python3 -I -c 'import json, sys; m = json.loads(sys.argv[1]); m["colours"] = m.get("colours", []) + m["sidebar"].get("colours", []); print(json.dumps(m))' "${measures}")" "${expected}"
	done
	measures="$(output="${site}/sections/appendix-a-listings.html" measure 1440 900 "" nav)"
	expect "html-full-chapter-header-appendix" "the appendix kicker and the In this chapter list of the appendix page" \
		chapter_header "${measures}" Appendix '["A.1 Individual subject data listings", "A.2 Adverse event listings"]'
	measures="$(output="${page}" measure 1440 900 forced nav)"
	expect "html-book-sidebar-current-forced-colors" "a visible mark of the current page in forced colours" \
		measured "${measures}" 'any(v for k, v in m["sidebar"]["current"]["forced"].items() if k != "weight")' 'm["sidebar"]["current"]'
	measures="$(output="${page}" measure 1440 900 print nav)"
	expect "html-book-print-hidden" "no sidebar and no contents in print" \
		measured "${measures}" 'm["sidebar"]["printDisplay"] == "none" and "none" in m["toc"]["printDisplay"]' '(m["sidebar"]["printDisplay"], m["toc"]["printDisplay"])'
	measures="$(output="${page}" measure 1440 900 reduced nav)"
	expect "html-book-reduced-motion" "no sidebar transition under reduced motion" measured "${measures}" 'not any(m["sidebar"]["motion"])' 'm["sidebar"]["motion"]'
	measures="$(output="${page}" measure 800 900 "" nav)"
	expect "html-book-drawer-closed" "below 992 pixels, the sidebar is a closed drawer behind a menu button of 24 pixels or more" \
		measured "${measures}" 'not m["sidebar"]["shown"] and m["menu"]["shown"] and m["menu"]["width"] >= 24 and m["menu"]["height"] >= 24 and m["menuColour"]["ratio"] >= 3' '(m["sidebar"]["shown"], m.get("menu"), m.get("menuColour"))'
	expect "html-book-scroll-offset" "anchors clear of the fixed header" \
		measured "${measures}" 'max(m["scroll"]["paddingTop"], m["scroll"]["headingMargin"]) >= m["scroll"]["header"]' 'm["scroll"]'
	measures="$(output="${page}" measure 800 900 open nav)"
	expect "html-book-drawer-open" "the menu button opens the drawer, text at 4.5:1" \
		measured "${measures}" 'm.get("drawer") and m["drawer"]["shown"] and m["drawer"]["expanded"] == "true" and all(c["ratio"] >= 4.5 for c in m["drawer"]["colours"])' 'm.get("drawer")'

	expect "html-axe-book" "no axe-core finding on the book pages in light and dark, at 1440, 768 and 320 pixels" \
		axe_clean "*.html,sections/*.html" 1440x900,768x1024,320x568 "${site}"
	expect "html-book-style" "sidebar rules scoped to the gold preset" preset_rule "${light_css}" gold '\.sidebar'
}

# Check the chapter header of a single document in the full layout: each
# level 1 heading has its "In this chapter" list.
check_full() {
	local measures
	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	measures="$(measure 1440 900 "" nav)"
	expect "html-full-chapter-header" "a chapter list after each chapter heading, one link for each section" \
		measured "${measures}" 'm.get("chapters") == [["1.1 Objectives", "1.1.1 Secondary objectives", "1.2 Design"], ["2.1 Primary outcome", "2.2 Safety"]] and all(c["ratio"] >= 4.5 for c in m["chapter"]["colours"])' '(m.get("chapters"), m.get("chapter"))'
	expect "html-full-chapter-header-name" "each list named by its title and its chapter, not by the chapter text" \
		measured "${measures}" 'm.get("chapterNames") == ["In this chapter, 1 Study design", "In this chapter, 2 Results"]' 'm.get("chapterNames")'
	expect "html-axe-full" "no axe-core finding in light and dark, at 1440 and 320 pixels" axe_clean
}

# Check the overlap toggle that Quarto puts in place of the contents when
# margin content sits beside it. Quarto builds the toggle from an
# IntersectionObserver, so html-overlap-probe.mjs opens the page in a browser
# session in real time (Node.js). When the toggle is built, it must be a real
# button (quarto-cli#14969, a TODO until fixed); when the browser does not
# build it, the check is skipped and says so, since it then proves nothing.
check_overlap() {
	local probe status=0
	need node
	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	probe="$(node "${tests_dir}/_checks/html-overlap-probe.mjs" "${browser}" "${output}" 1440 900)" || status=$?
	[ -n "${probe}" ] || probe='{}'
	expect "html-toc-overlap-probe" "the probe ran on a page with margin content beside the contents" \
		measured "${probe}" 'm.get("margin") is True' 'm'
	[ "${status}" -eq 0 ] || return 0
	if measured "${probe}" 'm["toggle"]' 'm' >/dev/null; then
		expect_todo "html-toc-overlap-button" "quarto-cli#14969" \
			measured "${probe}" 'm["button"] and m["expanded"] in ("true", "false") and m["controls"] and m["closedInert"] and m["originalOut"]' 'm'
	else
		tap_n=$((tap_n + 1))
		printf 'ok %d - html-toc-overlap-button # SKIP toggle not built (headless): %s\n' "${tap_n}" "${probe}"
	fi
}

# Check that a document in a subdirectory of a project finds the fonts and the motif.
check_subdir() {
	structure="$(structure_report)"
	expect "subdir-assets-html-fonts" "local @font-face files beside the output" html_fonts_local
	expect "subdir-assets-html-motif" "the motif in the title block" structure_ok motif-in-title-block
}

# Answer the banner a memo case expects: the kind label, then one label=value
# line for each field, in the order of the kind. The "missing" case is a note
# that leaves out the from field.
# $1 case: a memo kind, or missing.
memo_expected() {
	case "$1" in
	note) printf '%s\n' Note 'To=Data team' 'From=M. Canouil' 'Date=11 Nov 2026' ;;
	missing) printf '%s\n' Note 'To=Data team' 'Date=11 Nov 2026' ;;
	minutes) printf '%s\n' Minutes 'Date and time=11 Nov 2026, 14:00' 'Present=MC, AA, BW' 'Absent=CD' ;;
	agenda) printf '%s\n' Agenda 'Date and time=18 Nov 2026, 10:00' 'Place=Room 4' 'Participants=MC, AA, BW, CD' ;;
	brief) printf '%s\n' Brief 'Date=11 November 2026' 'Audience=Product leads' 'Purpose=Agree the go or no go for the release' ;;
	esac
}

# Succeed when the memo banner holds the kind label in its kicker, and a
# definition list with exactly the expected terms and descriptions, in order:
# a field that has no value has no term, and no description.
# $1 case, see memo_expected.
memo_banner_fields() {
	local expected
	expected="$(memo_expected "$1")"
	python3 -I - "${output}" "${expected}" <<'PY'
import sys
from html.parser import HTMLParser

expected = sys.argv[2].split("\n")
VOID = ("br", "img", "path", "stop", "circle", "rect", "meta", "link", "input", "hr")


class Banner(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.banner = False
        self.kicker = ""
        self.terms = []
        self.descriptions = []
        self.lists = 0
        self.target = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = (attrs.get("class") or "").split()
        if tag == "header" and attrs.get("id") == "title-block-header":
            self.depth = 1
            self.banner = "mc-memo-banner" in classes
            return
        if not self.depth:
            return
        if tag not in VOID:
            self.depth += 1
        if tag == "p" and "mc-kicker" in classes:
            self.target = "kicker"
        elif tag == "dl" and "mc-memo-fields" in classes:
            self.lists += 1
        elif tag == "dt" and self.lists:
            self.terms.append("")
            self.target = "dt"
        elif tag == "dd" and self.lists:
            self.descriptions.append("")
            self.target = "dd"

    def handle_endtag(self, tag):
        if self.depth and tag not in VOID:
            self.depth -= 1
        if tag in ("p", "dt", "dd"):
            self.target = None

    def handle_data(self, data):
        if self.target == "kicker":
            self.kicker += data
        elif self.target == "dt":
            self.terms[-1] += data
        elif self.target == "dd":
            self.descriptions[-1] += data


page = Banner()
page.feed(open(sys.argv[1], encoding="utf-8").read())
want_fields = [tuple(line.split("=", 1)) for line in expected[1:]]
found = list(zip([t.strip() for t in page.terms], [d.strip() for d in page.descriptions]))
problems = []
if not page.banner:
    problems.append("the title block has no mc-memo-banner class")
if page.kicker.strip() != expected[0]:
    problems.append("kicker %r, expected %r" % (page.kicker.strip(), expected[0]))
if page.lists != 1:
    problems.append("%d dl.mc-memo-fields, expected 1" % page.lists)
if found != want_fields:
    problems.append("fields %r, expected %r" % (found, want_fields))
for problem in problems:
    print("# " + problem)
sys.exit(1 if problems else 0)
PY
}

# Succeed when the measures of a memo page show the banner and the band on the
# ground gradient of the preset, and every text on them has a contrast of 4.5:1
# or more against both ends of the gradient.
# $1 measures, as JSON. $2 ground-1 of the scheme. $3 ground-2 of the scheme.
ground_contrast() {
	python3 -I -c '
import json, sys
m = json.loads(sys.argv[1])
samples = m.get("ground")
if not samples:
    sys.exit("# no ground measures: " + sys.argv[1][:200])
problems = []
labels = {s["label"] for s in samples}
for needed in ("kicker", "title", "term", "description", "band"):
    if needed not in labels:
        problems.append("no %s sample" % needed)
for s in samples:
    if [x.lower() for x in s["stops"]] != [sys.argv[2].lower(), sys.argv[3].lower()]:
        problems.append("%s %r: gradient %s, expected %s %s" % (s["label"], s["text"], s["stops"], sys.argv[2], sys.argv[3]))
    elif min(s["ratios"]) < 4.5:
        problems.append("%s %r: %s on %s = %.2f" % (s["label"], s["text"], s["fg"], s["stops"], min(s["ratios"])))
for problem in problems[:12]:
    print("# " + problem)
sys.exit(1 if problems else 0)
' "$1" "$2" "$3"
}

# Check the HTML memo of one case and preset.
# $1 case: a memo kind, or missing. $2 preset.
check_memo() {
	local case="$1" preset="$2" size measures scheme mode
	structure="$(structure_report)"
	expect "memo-html-${case}-${preset}" "the kind label, and the fields of the kind in order with none empty, in dl.mc-memo-fields" \
		memo_banner_fields "${case}"
	expect "memo-html-landmark-header-${case}-${preset}" "one banner landmark" structure_ok landmark-header
	expect "memo-html-landmark-main-${case}-${preset}" "one main landmark" structure_ok landmark-main
	expect "memo-html-landmark-footer-${case}-${preset}" "one footer landmark" structure_ok landmark-footer
	expect "memo-html-motif-${case}-${preset}" "the motif in the banner" structure_ok motif-in-title-block
	expect "memo-html-motif-aria-${case}-${preset}" "aria-hidden on the motif" structure_ok motif-aria-hidden
	expect "memo-html-band-${case}-${preset}" "the footer slots in the band" has "${output}" 'class="mc-page-footer mc-memo-band'

	browser="$(find_browser)"
	if [ -z "${browser}" ]; then
		printf 'Bail out! no Chromium browser; set CHROME_PATH\n'
		exit 1
	fi
	for size in 1440,900 320,568; do
		measures="$(measure "${size%,*}" "${size#*,}")"
		expect "memo-html-motif-flush-${case}-${preset}-${size%,*}" "the motif flush in the top right corner, no text over it or the toggle" \
			flush_corner "${measures}"
	done
	for scheme in light dark; do
		mode="${scheme}"
		[ "${preset}" != terminal ] || mode=dark
		measures="$(measure 1440 900 "${scheme}")"
		expect "memo-html-contrast-${case}-${preset}-${scheme}" "banner and band text at 4.5:1 or more on both gradient ends, the gradient from ground-1 to ground-2" \
			ground_contrast "${measures}" "$(preset_value "${preset}" "${mode}" ground-1)" "$(preset_value "${preset}" "${mode}" ground-2)"
	done
	measures="$(measure 1440 900 forced)"
	expect "memo-html-forced-colors-${case}-${preset}" "motif, rules, banner and band gradients hidden in forced colours" decorations_hidden "${measures}"
	expect "memo-html-axe-${case}-${preset}" "no axe-core finding in light and dark, at 1440 and 320 pixels" axe_clean
}

structure=""
browser=""
case "${1:-}" in
title) check_title "${2:?title needs a preset}" ;;
components) check_components "${2:?components needs a preset}" ;;
toc) check_toc "${2:?toc needs a preset}" ;;
memo) check_memo "${2:?memo needs a case}" "${3:?memo needs a preset}" ;;
book) check_book ;;
full) check_full ;;
overlap) check_overlap ;;
subdir) check_subdir ;;
measure)
	browser="$(find_browser)"
	measure "${2:?measure needs a width}" "${3:?measure needs a height}" "${4:-}" "${5:-nav}"
	exit 0
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
