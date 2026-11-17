#!/usr/bin/env bash
set -euo pipefail

# Check hook of the test book: the Typst checks of types.sh for the PDF, the
# HTML checks of html.sh for the book website.
#
# @license MIT
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil

here="$(dirname "${BASH_SOURCE[0]}")"
case "${EXTENSION_TEST_FORMAT##*-}" in
typst) exec bash "${here}/types.sh" book ;;
html) exec bash "${here}/html.sh" book ;;
*)
	printf '# book.sh does not apply to the %s format\n' "${EXTENSION_TEST_FORMAT:-}"
	exit 77
	;;
esac
