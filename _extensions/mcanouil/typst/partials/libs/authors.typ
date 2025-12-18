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

// Author formatting functions
// Processes Quarto's normalised author schema
// Reference: https://quarto.org/docs/journals/authors.html
// Author: Mickaël Canouil
// License: MIT

// Import shared utilities
// #import "utilities.typ": has-content, is-empty, content-to-str, unescape-email

// ============================================================================
// Author name formatting
// ============================================================================

/// Format a single author's name from schema
/// @param author Author dictionary from Quarto normalised schema
/// @return Formatted author name as content
#let format-author-name(author) = {
  if has-content(author.name.literal) {
    author.name.literal
  } else {
    let parts = ()
    if has-content(author.name.given) {
      parts.push(author.name.given)
    }
    if has-content(author.name.family) {
      parts.push(author.name.family)
    }
    if parts.len() > 0 {
      parts.join(" ")
    } else {
      [Unknown Author]
    }
  }
}

/// Format a single author's name as string (for PDF metadata)
/// @param author Author dictionary from Quarto normalised schema
/// @return Formatted author name as string
#let format-author-name-str(author) = {
  content-to-str(format-author-name(author))
}

/// Get author contact information with fallback priority
/// Priority: url → email → first affiliation name
/// @param author Author dictionary from Quarto normalised schema
/// @return Contact information as content or none
#let format-author-contact(author) = {
  // Try URL first
  if has-content(author.url) {
    let url-str = if type(author.url) == str {
      author.url
    } else {
      content-to-str(author.url)
    }
    // Remove escaped backslashes from Pandoc (e.g., https:\/\/ -> https://)
    url-str = url-str.replace("\\/", "/")
    // Remove protocol prefix for display
    let display-url = url-str.replace("https://", "").replace("http://", "")
    return link(url-str)[#display-url]
  }

  // Fall back to email
  if has-content(author.email) {
    let clean-email = unescape-email(author.email)
    return link("mailto:" + clean-email)[#clean-email]
  }

  // Fall back to first affiliation name
  if author.affiliations != none and author.affiliations.len() > 0 {
    let first-aff = author.affiliations.at(0)
    if has-content(first-aff.name) {
      return first-aff.name
    }
  }

  // No contact information available
  none
}

// ============================================================================
// Affiliation management
// ============================================================================

/// Collect all unique affiliations from authors
/// @param authors Array of author dictionaries
/// @return Tuple of (affiliations-list, author-affiliation-map)
#let collect-affiliations(authors) = {
  let affiliations = ()
  let aff-map = (:) // Maps affiliation key to index

  for author in authors {
    if author.affiliations != none {
      for aff in author.affiliations {
        // Create a key from affiliation details
        let parts = ()
        if has-content(aff.department) { parts.push(content-to-str(aff.department)) }
        if has-content(aff.name) { parts.push(content-to-str(aff.name)) }
        if has-content(aff.city) { parts.push(content-to-str(aff.city)) }
        if has-content(aff.country) { parts.push(content-to-str(aff.country)) }
        let key = parts.join("|")

        if key not in aff-map {
          aff-map.insert(key, affiliations.len() + 1)
          affiliations.push(aff)
        }
      }
    }
  }

  (affiliations, aff-map)
}

/// Get affiliation indices for an author
/// @param author Author dictionary
/// @param aff-map Affiliation key to index mapping
/// @return Array of affiliation indices
#let get-author-aff-indices(author, aff-map) = {
  let indices = ()
  if author.affiliations != none {
    for aff in author.affiliations {
      let parts = ()
      if has-content(aff.department) { parts.push(content-to-str(aff.department)) }
      if has-content(aff.name) { parts.push(content-to-str(aff.name)) }
      if has-content(aff.city) { parts.push(content-to-str(aff.city)) }
      if has-content(aff.country) { parts.push(content-to-str(aff.country)) }
      let key = parts.join("|")
      if key in aff-map {
        indices.push(aff-map.at(key))
      }
    }
  }
  indices
}

// ============================================================================
// Author display formatting
// ============================================================================

/// Format author with affiliation superscripts and markers
/// @param author Author dictionary
/// @param colours Colour dictionary
/// @param aff-map Affiliation key to index mapping
/// @return Formatted author name with markers
#let format-author(author, colours, aff-map: (:)) = {
  let name = format-author-name(author)
  let result = [#strong(name)]

  // Add affiliation superscript numbers as internal links (no underline styling)
  let indices = get-author-aff-indices(author, aff-map)
  if indices.len() > 0 {
    let linked-indices = indices.map(i => link(label("aff-" + str(i)))[#str(i)])
    result = [#result#super[#linked-indices.join(",")]]
  }

  // Add corresponding author marker
  if author.attributes != none and author.attributes.corresponding == true {
    result = [#result#super[\*]]
  }

  // Add equal contributor marker
  if author.attributes != none {
    let equal = author.attributes.at("equal-contributor", default: false)
    if equal == true {
      result = [#result#super[#sym.dagger]]
    }
  }

  result
}

/// Format affiliations for display (legacy function, not currently used)
/// @param affiliations Array of affiliation dictionaries
/// @param colours Colour dictionary
/// @return Formatted affiliations text
#let format-affiliations(affiliations, colours) = {
  let aff-texts = ()
  for aff in affiliations {
    let parts = ()
    if has-content(aff.department) {
      parts.push(aff.department)
    }
    if has-content(aff.name) {
      parts.push(aff.name)
    }
    if has-content(aff.city) and has-content(aff.country) {
      parts.push([#aff.city, #aff.country])
    } else if has-content(aff.city) {
      parts.push(aff.city)
    } else if has-content(aff.country) {
      parts.push(aff.country)
    }
    if parts.len() > 0 {
      aff-texts.push(parts.join(", "))
    }
  }
  if aff-texts.len() > 0 {
    text(size: 9pt, fill: colours.muted)[#aff-texts.join("; ")]
  }
}

/// Complete author block with all authors
/// Affiliations shown separately below abstract
/// @param authors Array of author dictionaries
/// @param colours Colour dictionary
/// @param aff-map Affiliation key to index mapping
/// @return Formatted author block
#let author-block(authors, colours, aff-map: (:)) = {
  // Format all author names with affiliation superscripts and markers
  let author-names = authors.map(a => format-author(a, colours, aff-map: aff-map))

  align(center)[
    // Author names line only
    #text(size: 11pt)[#author-names.join(", ", last: " and ")]
  ]
}

/// Affiliations and ORCID section (displayed below abstract)
/// @param authors Array of author dictionaries
/// @param affiliations Array of affiliation dictionaries
/// @param colours Colour dictionary
/// @param orcid-icon Path to ORCID icon file
/// @return Formatted affiliations section
#let affiliations-section(authors, affiliations, colours, orcid-icon: none) = {
  block(
    width: 100%,
    inset: (left: 2em, right: 2em),
    [
      // Numbered affiliations list with labels for linking
      #if affiliations.len() > 0 {
        text(weight: "bold", size: 10pt)[Affiliations]
        v(0.3em)
        for (idx, aff) in affiliations.enumerate() {
          let parts = ()
          if has-content(aff.department) { parts.push(aff.department) }
          if has-content(aff.name) { parts.push(aff.name) }
          if has-content(aff.city) and has-content(aff.country) {
            parts.push([#aff.city, #aff.country])
          } else if has-content(aff.city) {
            parts.push(aff.city)
          } else if has-content(aff.country) {
            parts.push(aff.country)
          }
          if parts.len() > 0 {
            [#text(size: 9pt, fill: colours.muted)[
                #super[#str(idx + 1)] #parts.join(", ")
              ]#label("aff-" + str(idx + 1))]
            linebreak()
          }
        }
        v(0.5em)
      }

      // ORCID links
      #{
        let orcid-authors = authors.filter(a => a.orcid != none)
        if orcid-authors.len() > 0 {
          text(weight: "bold", size: 10pt)[ORCID]
          v(0.3em)
          for author in orcid-authors {
            let name = format-author-name(author)
            let orcid-url = "https://orcid.org/" + author.orcid
            if orcid-icon != none {
              text(size: 9pt, fill: colours.muted)[
                #name: #link(orcid-url)[#box(baseline: 0.1em, image(orcid-icon.replace("\\", ""), width: 10pt)) #author.orcid]
              ]
            } else {
              text(size: 9pt, fill: colours.muted)[
                #name: #link(orcid-url)[#author.orcid]
              ]
            }
            linebreak()
          }
          v(0.5em)
        }
      }

      // Corresponding author note
      #for author in authors {
        if author.attributes != none and author.attributes.corresponding == true {
          if author.email != none {
            let clean-email = unescape-email(author.email)
            text(size: 9pt, fill: colours.muted)[
              #super[\*]Corresponding author: #link("mailto:" + clean-email)[#clean-email]
            ]
          }
        }
      }
    ],
  )
}
