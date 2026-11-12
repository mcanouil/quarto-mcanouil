#!/usr/bin/env bash
set -euo pipefail

# Check hook: the tokens of a preset reach the HTML, Reveal.js and Typst output.
#
# Usage: tokens.sh smoke <preset>
#        tokens.sh default
#        tokens.sh dark-deck
#        tokens.sh user-background
#        tokens.sh user-brand
#        tokens.sh terminal-light
#        tokens.sh typst-dark
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Succeed when every @font-face URL of the fonts.css linked from the HTML
# output names a file that exists, and the output makes no request to a font
# service.
html_fonts_local() {
	local css url found=0
	css="$(grep -oE 'href="[^"]*fonts\.css"' "${output}" | head -n 1 | sed -E 's/^href="(.*)"$/\1/')"
	[ -n "${css}" ] || return 1
	css="$(dirname "${output}")/${css}"
	[ -f "${css}" ] || return 1
	while IFS= read -r url; do
		[ -f "$(dirname "${css}")/${url}" ] || return 1
		found=1
	done < <(grep -oE 'url\("[^"]+"\)' "${css}" | sed -E 's/^url\("(.*)"\)$/\1/')
	[ "${found}" = 1 ] && lacks "${output}" 'fonts.googleapis' && lacks "${output}" 'fonts.gstatic'
}

# Succeed when the Bootstrap stylesheet linked from the HTML output colours
# links with the link token.
links_use_token() {
	local css
	css="$(dirname "${output}")/$(grep -oE 'href="[^"]*bootstrap-[0-9a-f]+\.min\.css"' "${output}" | head -n 1 | sed -E 's/^href="(.*)"$/\1/')"
	[ -f "${css}" ] && grep -qF 'color:var(--mc-link)' "${css}"
}

# Succeed when the PDF embeds a font.
# $1 font name.
pdf_embeds() {
	pdffonts "${output}" | grep -q "$1"
}

# Succeed when the PDF has one page.
one_page() {
	[ "$(pdf_page_count "${output}")" = "1" ]
}

# Succeed when the output does not reach a token with a colour.
# $1 token. $2 hex colour.
not_reaches() {
	! reaches "$1" "$2"
}

# Succeed when the document sets no preset.
sets_no_preset() {
	! grep -qE '^[[:space:]]+preset:' "${EXTENSION_TEST_INPUT}"
}

# Check the render of the smoke document with one preset.
# $1 preset.
check_smoke() {
	local preset="$1" accent
	accent="$(preset_value "${preset}" light accent-text)"
	expect "preset-${preset}-reaches-${format}" "accent-text ${accent} of ${preset} in the ${format} output" \
		reaches accent-text "${accent}"
	if [ "${preset}" = mono ]; then
		expect "preset-select-mono-${format}" "mono accent-text, and not gold, in the ${format} output" \
			not_reaches accent-text "$(preset_value gold light accent-text)"
	fi
	case "${format}" in
	html)
		expect "html-dark-tokens-${preset}" "dark paper of ${preset} in body.quarto-dark" \
			css_token 'body.quarto-dark' paper "$(preset_value "${preset}" dark paper)"
		if [ "${preset}" = terminal ]; then
			expect "html-dark-tokens-terminal-light" "terminal dark paper in body.quarto-light" \
				css_token 'body.quarto-light' paper "$(preset_value terminal dark paper)"
			expect "link-token-html" "terminal --mc-link $(preset_value terminal dark link) in HTML" \
				css_token 'body.quarto-light' link "$(preset_value terminal dark link)"
			expect "link-token-bootstrap" "links coloured by var(--mc-link)" links_use_token
		fi
		if [ "${preset}" = gold ]; then
			expect "fonts-embedded-html-gold" "local @font-face files and no font service" html_fonts_local
		fi
		if [ "${preset}" = mono ]; then
			expect "fonts-embedded-font-base" "--mc-font-base Alegreya Sans" \
				css_token 'body.quarto-light' font-base '"Alegreya Sans", sans-serif'
		fi
		;;
	revealjs)
		if [ "${preset}" = mono ]; then
			expect "fonts-embedded-revealjs-mono" "local @font-face files and no font service" html_fonts_local
		fi
		;;
	typst)
		need pdfinfo
		need pdffonts
		expect "smoke-renders-typst-${preset}" "one PDF page" one_page
		if [ "${preset}" = terminal ]; then
			expect "link-token-typst" "terminal link $(preset_value terminal dark link) in the Typst tokens" \
				typ_token link "$(preset_value terminal dark link)"
			expect "fonts-embedded-typst-terminal" "JetBrains Mono in the PDF" pdf_embeds JetBrainsMono
		fi
		if [ "${preset}" = gold ]; then
			expect "fonts-embedded-typst-gold" "Source Serif 4 in the PDF" pdf_embeds SourceSerif4
		fi
		;;
	esac
}

# Check that no preset is set, so the default preset applies.
check_default() {
	local accent
	accent="$(preset_value gold light accent-text)"
	expect "preset-default-gold-${format}" "gold accent-text ${accent} when no preset is set" reaches accent-text "${accent}"
	expect "preset-default-gold-unset-${format}" "no preset key in the test document" sets_no_preset
}

# Check the dark tokens of a Reveal.js deck with brand-mode: dark.
check_dark_deck() {
	local token
	for token in paper ink accent-text; do
		expect "reveal-dark-tokens-${token}" "the gold dark ${token} in :root of the deck" \
			css_token ':root' "${token}" "$(preset_value gold dark "${token}")"
	done
	expect "reveal-dark-tokens-ground" "the gold dark paper in the dark and ground slide rule" \
		css_token '.reveal .slides section.dark, .reveal .slides section.mc-ground' paper "$(preset_value gold dark paper)"
}

# Check that the dark background of a user brand reaches the dark rules.
check_user_background() {
	expect "user-background-dark-dark" "the user dark background in body.quarto-dark" \
		css_token 'body.quarto-dark' paper '#202020'
	expect "user-background-dark-light" "the user light background in body.quarto-light" \
		css_token 'body.quarto-light' paper '#ffffff'
}

# Check that a partial user brand overrides the accent, and keeps the preset ground.
check_user_brand() {
	local ground
	ground="$(preset_value gold light ground-1)"
	expect "partial-user-brand-accent-${format}" "user primary #ff0000 as accent in the ${format} output" reaches accent '#ff0000'
	expect "partial-user-brand-ground-${format}" "preset ground-1 ${ground} in the ${format} output" reaches ground-1 "${ground}"
}

# Check that a light request on the dark-only terminal preset gives dark tokens.
check_terminal_light() {
	local paper
	paper="$(preset_value terminal dark paper)"
	if [ "${format}" = typst ]; then
		expect "terminal-light-warns-typst-paper" "dark terminal paper ${paper} in the Typst tokens" typ_token paper "${paper}"
	else
		expect "terminal-light-warns-html-paper" "dark terminal paper ${paper} in body.quarto-light" \
			css_token 'body.quarto-light' paper "${paper}"
	fi
}

# Check that the page 1 of a brand-mode: dark PDF has the dark paper.
check_typst_dark() {
	need pdftoppm
	local image width
	image="$(page1_image)"
	read -r width _ <<<"$(ppm_size "${image}")"
	expect "typst-dark-mode-paper" "the gold dark paper on page 1" \
		test "$(colour_distance "$(pixel "${image}" $((width * 3 / 10)) 3)" "$(hex_rgb "$(preset_value gold dark paper)")")" -le 3
}

case "${1:-}" in
smoke) check_smoke "${2:?smoke needs a preset}" ;;
default) check_default ;;
dark-deck) check_dark_deck ;;
user-background) check_user_background ;;
user-brand) check_user_brand ;;
terminal-light) check_terminal_light ;;
typst-dark) check_typst_dark ;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
