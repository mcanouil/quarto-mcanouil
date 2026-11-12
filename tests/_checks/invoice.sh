#!/usr/bin/env bash
# shellcheck disable=SC2154 # format, output, typ, ext_dir, tests_dir and tap_n are set by lib.sh
set -euo pipefail

# Check hook: the invoice document type, read from the PDF text, the word boxes and the tag tree.
#
# Usage: invoice.sh totals | exempted | fr | din
#
# The fixtures hold three items and two VAT rates:
#   2 x 1200.00 + 3 x 33.33 at 20 %, 1 x 24.50 at 5.5 %
#   subtotal 2524.49, VAT 20 % 500.00 (499.998 rounded), VAT 5.5 % 1.35 (1.3475 rounded), total 3025.84
#
# Exits 77 for a format other than Typst.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

# shellcheck source=/dev/null # lib.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${format}" = typst ] || skip_format invoice.sh
need pdftotext
need pdftoppm
need pdfinfo

# shellcheck source=/dev/null # address.sh is checked on its own
source "$(dirname "${BASH_SOURCE[0]}")/address.sh"

# Answer the text of the PDF with every kind of no-break space written as a plain space.
flat_text() {
	pdf_text "${output}" | sed -e $'s/\xc2\xa0/ /g' -e $'s/\xe2\x80\xaf/ /g' | tr -s '[:space:]' ' '
}

# Succeed when the text of the PDF holds every given string, in order.
# $@ strings.
flat_in_order() {
	local rest needle
	rest="$(flat_text)"
	for needle in "$@"; do
		case "${rest}" in
		*"${needle}"*) rest="${rest#*"${needle}"}" ;;
		*) return 1 ;;
		esac
	done
}

# Succeed when the text of the PDF holds a string.
# $1 string.
flat_has() {
	flat_text | grep -qF -- "$1"
}

# Succeed when the text of the PDF lacks a string.
# $1 string.
flat_lacks() {
	! flat_has "$1"
}

# Succeed when the tag tree holds at least a number of header cells (TH).
# $1 minimum.
header_cells_at_least() {
	local count
	count="$(pdfinfo -struct-text "${output}" | grep -cE '^[[:space:]]*TH\b' || true)"
	[ "${count}" -ge "$1" ]
}

case "${1:-}" in
totals)
	find_verapdf
	expect "invoice-totals-line" "3 x 33.33 is 99.99 on its line" flat_in_order "Material" "33.33" "99.99"
	expect "invoice-totals-subtotal" "the subtotal, each VAT rate and the total, in order" flat_in_order "Subtotal" "2,524.49" "VAT 20 %" "500.00" "VAT 5.5 %" "1.35" "Total" "3,025.84"
	expect "invoice-totals-currency" "the currency symbol on the total" flat_has "€3,025.84"
	expect "invoice-table-headers" "tagged header cells for the five columns" header_cells_at_least 5
	expect "invoice-ua1" "veraPDF ua1 compliance" verapdf_ua1 "${output}"
	expect "invoice-window" "the recipient in the NF window at x 110, y 50, 80 by 35 mm" recipient_in_window Company France 110 50 80 35
	expect "invoice-sender-left" "the sender at the left margin" word_x_between Mickaël 19 22
	expect "invoice-legal-line" "the registration and the VAT number after the terms" flat_in_order "Terms" "Registration number 123 456 789" "VAT number FR1234567890"
	expect "invoice-fold-marks" "fold marks at 99 and 198 mm" marks_at 99 198
	expect "invoice-payment" "the payment box with the bank details and the reference" flat_in_order "Payment" "AZERTYUI" "FR12 1234 4567 7890 1234 5678 901" "REF-2026-014"
	expect "invoice-terms" "the terms with the days to pay, the late fee and the penalty" flat_in_order "Terms" "30 days" "2.28" "40"
	expect "invoice-dates" "the dates in the reference block" flat_in_order "2026-014" "2026-11-01" "2026-12-01"
	;;
exempted)
	expect "invoice-exempted-mention" "the exemption mention" flat_has "VAT exempt"
	expect "invoice-exempted-no-vat-line" "no VAT line" flat_lacks "VAT 20"
	expect "invoice-exempted-no-vat-line-reduced" "no reduced-rate VAT line" flat_lacks "VAT 5.5"
	expect "invoice-exempted-no-vat-column" "no VAT column" flat_lacks "20 %"
	expect "invoice-exempted-no-subtotal" "no subtotal line" flat_lacks "Subtotal"
	expect "invoice-exempted-total" "the total without VAT" flat_in_order "Total" "2,524.49"
	;;
fr)
	expect "invoice-fr-labels" "the French labels" flat_in_order "Facture" "Désignation" "Quantité" "Prix unitaire" "TVA" "Sous-total"
	expect "invoice-fr-money" "the French number format and the euro after the amount" flat_in_order "Sous-total" "2 524,49 €" "TVA 20 %" "500,00 €" "TVA 5,5 %" "1,35 €" "Total" "3 025,84 €"
	expect "invoice-fr-window" "the recipient in the NF window" recipient_in_window Company France 110 50 80 35
	expect "invoice-fr-terms" "the French terms" flat_in_order "Conditions" "30 jours"
	;;
din)
	expect "invoice-din-window" "the recipient in the DIN window at x 20, y 45, 85 by 45 mm" recipient_in_window Company Germany 20 45 85 45
	expect "invoice-din-reference-block" "the dates in the reference block at x 125" word_x_between Issued 124 127
	expect "invoice-din-sender-right" "the sender above the reference block at x 125" word_x_between Mickaël 124 127
	expect "invoice-din-fold-marks" "fold marks at 105 and 210 mm, punch mark at 148.5 mm" marks_at 105 210 148.5
	;;
*)
	printf 'Bail out! unknown case %s\n' "${1:-}"
	exit 1
	;;
esac
tap_done
