--[[
MIT License

Copyright (c) 2026 Mickael Canouil

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

---@module 'section-slides'
---@description Adds data-background-color to section slides (H1 headings) for Reveal.js
---@author Mickael Canouil

-- Section slide configuration
local section_bg = '#333333' -- Default dark background (inverted from body)

--- Check if the output format is revealjs
---@return boolean
local function is_revealjs()
  return quarto.doc.is_format('revealjs')
end

--- Process metadata to extract section slide colours
---@return pandoc.Meta|nil
function Meta(meta)
  if not is_revealjs() then
    return nil
  end

  -- Read background colour from metadata (can be set via _extension.yml or document frontmatter)
  if meta['section-slide-background-color'] then
    section_bg = pandoc.utils.stringify(meta['section-slide-background-color'])
  end

  return nil
end

--- Process headers to add section slide attributes
---@return pandoc.Header|nil
function Header(header)
  if not is_revealjs() then
    return nil
  end

  -- Only process level 1 headings (section slides)
  if header.level ~= 1 then
    return nil
  end

  -- Skip if this is the title slide
  if header.classes:includes('title') then
    return nil
  end

  -- Add data-background-color attribute for Reveal.js
  -- This must be set BEFORE Reveal.js initialises (hence Lua filter, not JS)
  header.attr.attributes['data-background-color'] = section_bg

  -- Add section-slide class for CSS styling
  if not header.classes:includes('section-slide') then
    header.classes:insert('section-slide')
  end

  return header
end

return {
  { Meta = Meta },
  { Header = Header },
}
