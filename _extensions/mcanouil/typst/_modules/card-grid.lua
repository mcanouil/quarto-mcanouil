--[[
# MIT License
#
# Copyright (c) 2025 Mickaël Canouil
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

--- @module card-grid
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Handles card grid divs with complex card extraction
--- @description Mirrors partials/card-grid.typ

-- ============================================================================
-- MODULE IMPORTS
-- ============================================================================

local typst_utils = require(
  quarto.utils.resolve_path('../_modules/typst-utils.lua'):gsub('%.lua$', '')
)

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Extract card data from a div
--- Extracts title from first heading, splits content by horizontal rule
--- @param div pandoc.Div The card div
--- @return table Card data with title, content, footer, style, colour
local function extract_card(div)
  local card = {}

  -- Get style and colour from attributes
  card.style = div.attributes.style
  card.colour = div.attributes.colour

  local blocks = pandoc.List(div.content)
  local content_blocks = pandoc.List()
  local footer_blocks = pandoc.List()
  local in_footer = false

  -- Process blocks
  for i, block in ipairs(blocks) do
    if block.t == 'Header' and not card.title then
      -- First heading becomes title
      card.title = pandoc.utils.stringify(block.content)
    elseif block.t == 'HorizontalRule' then
      -- Horizontal rule splits content and footer
      in_footer = true
    elseif in_footer then
      footer_blocks:insert(block)
    else
      -- Skip the heading that was used as title
      if block.t ~= 'Header' or card.title ~= pandoc.utils.stringify(block.content) then
        content_blocks:insert(block)
      end
    end
  end

  -- Convert blocks to strings
  if #content_blocks > 0 then
    card.content = pandoc.utils.stringify(content_blocks)
  end
  if #footer_blocks > 0 then
    card.footer = pandoc.utils.stringify(footer_blocks)
  end

  return card
end

-- ============================================================================
-- COMPONENT PROCESSING
-- ============================================================================

--- Process card-grid div
--- Extracts cards from child divs and builds Typst code
--- @param div pandoc.Div Card-grid div containing card divs
--- @param config table Component configuration (not used for card-grid special processing)
--- @return pandoc.RawBlock Typst code for rendering card grid
local function process_div(div, config)
  local cards = pandoc.List()
  local columns = div.attributes.columns and tonumber(div.attributes.columns) or 3

  -- Extract cards from child divs
  for _, block in ipairs(div.content) do
    if block.t == 'Div' and block.classes:includes('card') then
      local card = extract_card(block)
      if card.title or card.content or card.footer then
        cards:insert(card)
      end
    end
  end

  if #cards == 0 then
    return pandoc.Null()
  end

  -- Build cards array for Typst
  local card_items = {}
  for _, card in ipairs(cards) do
    local card_parts = {}

    if card.title then
      table.insert(card_parts, string.format('title: %s', typst_utils.typst_value(card.title)))
    end
    if card.content then
      table.insert(card_parts, string.format('content: %s', typst_utils.typst_value(card.content)))
    end
    if card.footer then
      table.insert(card_parts, string.format('footer: %s', typst_utils.typst_value(card.footer)))
    end
    if card.style then
      table.insert(card_parts, string.format('style: %s', typst_utils.typst_value(card.style)))
    end
    if card.colour then
      -- Hex colours need rgb() wrapper, other values use typst_value()
      if card.colour:match('^#') then
        table.insert(card_parts, string.format('colour: rgb(%s)', typst_utils.typst_value(card.colour)))
      else
        table.insert(card_parts, string.format('colour: %s', typst_utils.typst_value(card.colour)))
      end
    end

    table.insert(card_items, '(' .. table.concat(card_parts, ', ') .. ')')
  end

  -- Build Typst code
  local typst_code = string.format(
    '#mcanouil-card-grid(\n  (%s),\n  columns: %d\n)',
    table.concat(card_items, ',\n    '),
    columns
  )

  return pandoc.RawBlock('typst', typst_code)
end

-- ============================================================================
-- MODULE EXPORTS
-- ============================================================================

return {
  extract_card = extract_card,
  process_div = process_div
}
