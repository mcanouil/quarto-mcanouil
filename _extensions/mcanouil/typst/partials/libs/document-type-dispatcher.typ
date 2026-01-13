// MIT License
//
// Copyright (c) 2026 Mickaël Canouil
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Document Type Dispatcher
// Routes to appropriate template function based on document-type parameter.
// Author: Mickaël Canouil
// License: MIT

/// Supported document types
#let DOCUMENT_TYPES = "report" // ("report", "invoice", "letter", "cv")

/// Main document dispatcher function.
/// Routes to the appropriate template function based on document-type.
///
/// @param document-type The type of document to render ("report", "invoice", "letter", "cv").
/// @param body The document body content.
/// @param ..args All other parameters passed through to the template function.
/// @return The rendered document.
#let mcanouil-document(
  document-type: "report",
  ..args,
) = {
  // Validate and normalise document type
  let doc-type = if document-type in DOCUMENT_TYPES {
    document-type
  } else {
    // Fall back to report with warning
    "report"
  }

  // Dispatch to appropriate template
  // The body is passed as positional argument via args.pos()
  // Named arguments are passed via args.named()
  if doc-type == "invoice" {
    mcanouil-invoice(..args)
  } else if doc-type == "letter" {
    mcanouil-letter(..args)
  } else if doc-type == "cv" {
    mcanouil-cv(..args)
  } else {
    // Default: report
    mcanouil-report(..args)
  }
}
