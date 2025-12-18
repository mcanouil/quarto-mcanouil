// MIT License
//
// Copyright (c) 2025 Mickaël Canouil
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

// Special Section Numbering Functions
//
// Provides numbering functions for special document sections (appendix, supplementary).
// These functions are applied directly via Lua filter using #set heading(numbering: ...).
// Author: Mickaël Canouil
// License: MIT

// ============================================================================
// Numbering function factory
// ============================================================================

/// Factory for creating section numbering functions with optional prefix
/// @param pattern Numbering pattern string (e.g., "A.1.a.", "I.1.i.")
/// @param prefix Optional prefix for level 1 headings (e.g., "Appendix", "Supplementary")
/// @return Numbering function that formats heading numbers according to pattern
#let make-section-numbering(pattern, prefix: none) = {
  (..nums) => {
    let values = nums.pos()
    if values.len() == 0 {
      return ""
    }

    let number = numbering(pattern, ..values)
    if prefix != none and values.len() == 1 {
      [#prefix #number]
    } else {
      number
    }
  }
}

// ============================================================================
// Predefined numbering functions
// ============================================================================

/// Appendix numbering: "Appendix A", "A.a", "A.a.1" format
/// Level 1: "Appendix A"
/// Level 2+: "A.a", "A.a.1", etc.
#let appendix-numbering = make-section-numbering("A.a.1.", prefix: "Appendix")

/// Supplementary numbering: "Supplementary I", "I.i", "I.i.1" format
/// Level 1: "Supplementary I"
/// Level 2+: "I.i", "I.i.1", etc.
#let supplementary-numbering = make-section-numbering("I.i.1.", prefix: "Supplementary")

/// References numbering: none (unnumbered)
#let references-numbering = none
