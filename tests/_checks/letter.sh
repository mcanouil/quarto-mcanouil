#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the letter document type, read from the word boxes, the pixels and the PDF text.
#
# Usage: letter.sh nf | din | en | override | hex | hex-enabled | fields
#
# Window geometry, in millimetres from the top left of an A4 page:
#   NF Z 11-001: window at x 110, y 50, 80 wide and 35 high; fold marks at 99 and 198.
#   DIN 5008 form B: window at x 20, y 45, 85 wide and 45 high; reference block at x 125, y 50,
#   75 wide; fold marks at 105 and 210; punch mark at 148.5.
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format letter.sh
need pdftotext
need pdftoppm

# shellcheck source=/dev/null # address.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/address.sh"

nf_checks() {
	expect "letter-nf-window" "the recipient in the window at x 110, y 50, 80 by 35 mm" recipient_in_window Company Paris 110 50 80 35
	expect "letter-nf-fold-marks" "fold marks at 99 and 198 mm" marks_at 99 198
	expect "letter-nf-no-punch-mark" "no punch mark at 148.5 mm" no_mark_at 148.5
	expect "letter-nf-sender-left" "the sender at the left margin, above the window" word_x_between Mickaël 19 22
	expect "letter-nf-subject-below" "the subject below the window" word_below Proposition 85
}

case "${1:-}" in
nf)
	nf_checks
	expect "letter-nf-date" "the French place and date" page_has "Lille, le 11 novembre 2026"
	expect "letter-nf-subject-label" "the French subject label" page_has "Objet : Proposition de formation"
	;;
din)
	expect "letter-din-window" "the recipient in the window at x 20, y 45, 85 by 45 mm" recipient_in_window Beispiel München 20 45 85 45
	expect "letter-din-fold-marks" "fold marks at 105 and 210 mm, punch mark at 148.5 mm" marks_at 105 210 148.5
	expect "letter-din-reference-block" "the reference block at x 125 with the German labels" word_x_between Unser 124 127
	expect "letter-din-reference-block-text" "the references and the date in the block" in_order "Ihr Zeichen" "A-77" "Unser Zeichen" "2026-014" "Datum" "Berlin, 11. November 2026"
	expect "letter-din-no-english" "no English reference label" page_lacks Reference
	;;
en)
	expect "letter-en-nf-window" "the NF window for another language" recipient_in_window Company London 110 50 80 35
	expect "letter-en-date" "the English place and date" page_has "Lille, 11 November 2026"
	expect "letter-en-subject-label" "the English subject label" page_has "Subject: Training proposal"
	;;
override)
	expect "letter-override-din-window" "a French letter in the DIN window" recipient_in_window Company Paris 20 45 85 45
	expect "letter-override-french-date" "the French place and date in the DIN reference block" page_has "Lille, le 11 novembre 2026"
	;;
hex)
	expect "letter-hex-reference" "the reference prints as written" page_has "Reference: abcd1234"
	expect "letter-hex-no-badge" "no commit badge" page_lacks GitHub
	;;
hex-enabled)
	expect "letter-hex-enabled-badge" "gitlink enabled by the author turns the reference into a badge" page_has GitHub
	;;
fields)
	find_verapdf
	expect "letter-fields-order" "subject, opening, body, closing, cc, enclosures and postscript in order" in_order "Subject: Training proposal" "Dear Sir or Madam," "First paragraph" "Second paragraph" "Yours faithfully," "Mickaël Canouil" "Cc" "Alex Copy" "Enclosures" "Programme" "P.S." "Remember the date."
	expect "letter-fields-signature-image" "the signature image, with its alternative text" has_alt Signature
	expect "letter-fields-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
