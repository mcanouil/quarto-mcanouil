--[[
# MIT License
#
# Copyright (c) 2026 Mickaël Canouil
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
]]

--- @module special-sections
--- @author Mickaël Canouil
--- @version 2.0.0
--- @brief Simplified special sections filter for document reorganisation (Typst only)
--- @description Reorganises special section content (references, appendix, supplementary)
--- to document end and emits direct Typst commands for heading numbering.

--- Extension name constant
local EXTENSION_NAME = 'special-sections'

-- ============================================================================
-- FORMAT CHECK
-- ============================================================================

-- This filter only applies to Typst format
if not quarto.doc.is_format('typst') then
  return {}
end

-- ============================================================================
-- CONSTANTS AND STATE
-- ============================================================================

-- Configuration: Define supported special section types in order of appearance
-- References appears first, then appendix, then supplementary
local SPECIAL_SECTION_TYPES = {'references', 'appendix', 'supplementary'}

-- Storage for collected content by section type
local special_sections = {}
for _, section_type in ipairs(SPECIAL_SECTION_TYPES) do
  special_sections[section_type] = {
    content = pandoc.List(),
    has_content = false
  }
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Generate Typst code for section start
--- Emits direct commands to reset counter and set numbering function
--- @param section_type string Section type name
--- @return string Typst code to emit
local function generate_section_start(section_type)
  local lines = {}

  -- Comment for readability
  local capitalised = section_type:gsub('^%l', string.upper)
  table.insert(lines, string.format('// %s section start', capitalised))

  -- Reset heading counter
  table.insert(lines, '#counter(heading).update(0)')

  -- Set numbering function (predefined in special-sections.typ)
  if section_type == 'references' then
    table.insert(lines, '#set heading(numbering: none)')
  else
    table.insert(lines, string.format('#set heading(numbering: %s-numbering)', section_type))
  end

  return table.concat(lines, '\n')
end

--- Check if an element has a special section class
--- @param el pandoc.Block
--- @return string|nil The section type if found, nil otherwise
local function get_special_section_type(el)
  if el.classes then
    for _, section_type in ipairs(SPECIAL_SECTION_TYPES) do
      if el.classes:includes(section_type) then
        return section_type
      end
    end
  end
  return nil
end

-- ============================================================================
-- FILTER FUNCTIONS
-- ============================================================================

--- Collect blocks with special section classes.
--- Iterates through document blocks, identifies special section headers,
--- and collects their content for later repositioning.
--- @param blocks pandoc.List List of document blocks to process
--- @return pandoc.List Filtered blocks with special section content removed
function Blocks(blocks)
  local filtered_blocks = pandoc.List()
  local active_section = nil  -- Track current special section type
  local section_start_level = nil
  local current_blocks = pandoc.List()

  for _, block in ipairs(blocks) do
    -- Check if this block starts a special section
    local section_type = block.t == 'Header' and get_special_section_type(block) or nil

    if section_type then
      -- If we were already collecting blocks for another section, save them
      if active_section and #current_blocks > 0 then
        special_sections[active_section].content:extend(current_blocks)
        current_blocks = pandoc.List()
      end

      -- Start collecting content for this section type
      active_section = section_type
      section_start_level = block.level
      special_sections[section_type].has_content = true

      -- Remove the special section class from the header (we'll handle it in Typst)
      block.classes = block.classes:filter(function(c)
        return not pandoc.List(SPECIAL_SECTION_TYPES):includes(c)
      end)
      current_blocks:insert(block)
    elseif active_section then
      -- We're in a special section, collect this block
      current_blocks:insert(block)

      -- Check if we hit a non-special heading of same or higher level
      if block.t == 'Header' and not get_special_section_type(block) and block.level <= section_start_level then
        -- This ends the special section
        special_sections[active_section].content:extend(current_blocks)
        current_blocks = pandoc.List()
        active_section = nil
        section_start_level = nil
        -- Keep this block in the main content
        filtered_blocks:insert(block)
      end
    else
      -- Regular content, keep in main document
      filtered_blocks:insert(block)
    end
  end

  -- If we ended while still in a special section, add remaining blocks
  if active_section and #current_blocks > 0 then
    special_sections[active_section].content:extend(current_blocks)
  end

  return filtered_blocks
end

--- Add collected special section content to document end.
--- Appends all collected special section content to the document in defined order
--- (references, appendix, supplementary) with direct Typst commands.
--- @param doc pandoc.Pandoc The document to modify
--- @return pandoc.Pandoc Modified document with special sections appended
function Pandoc(doc)
  -- Append special sections in defined order
  for _, section_type in ipairs(SPECIAL_SECTION_TYPES) do
    local section = special_sections[section_type]

    if section.has_content and #section.content > 0 then
      -- Generate direct Typst commands for section start
      local typst_code = generate_section_start(section_type)
      local section_marker = pandoc.RawBlock('typst', typst_code)

      -- Append marker and all section content to document
      doc.blocks:insert(section_marker)
      doc.blocks:extend(section.content)
    end
  end

  return doc
end
