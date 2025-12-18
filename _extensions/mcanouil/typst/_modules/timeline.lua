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

--- @module timeline
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Handles timeline divs with complex event extraction
--- @description Mirrors partials/timeline.typ

-- ============================================================================
-- MODULE IMPORTS
-- ============================================================================

local typst_utils = require(
  quarto.utils.resolve_path('../_modules/typst-utils.lua'):gsub('%.lua$', '')
)
local utils = require(
  quarto.utils.resolve_path('../_modules/utils.lua'):gsub('%.lua$', '')
)

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Extract event data from a div
--- Supports both attribute-based and heading-based approaches
--- @param div pandoc.Div The event div
--- @return table Event data with date, title, and optional description
local function extract_event(div)
  local event = {}

  -- Get date and title from attributes if present
  event.date = div.attributes.date
  event.title = div.attributes.title

  -- If no title in attributes, try to extract from first heading
  if not event.title or event.title == '' then
    local blocks = pandoc.List(div.content)
    for i, block in ipairs(blocks) do
      if block.t == 'Header' then
        event.title = pandoc.utils.stringify(block.content)
        -- Remove the heading from content
        blocks:remove(i)
        break
      end
    end
    div.content = blocks
  end

  -- Description is remaining content
  if #div.content > 0 then
    event.description = pandoc.utils.stringify(div.content)
  end

  return event
end

-- ============================================================================
-- COMPONENT PROCESSING
-- ============================================================================

--- Process timeline div
--- Extracts events from child divs or headings and builds Typst code
--- @param div pandoc.Div Timeline div containing events
--- @param config table Component configuration (not used for timeline special processing)
--- @return pandoc.RawBlock Typst code for rendering timeline
local function process_div(div, config)
  local events = pandoc.List()
  local orientation = div.attributes.orientation or 'vertical'

  -- Auto-detect orientation from class name if not explicitly set
  if div.classes:includes('horizontal-timeline') then
    orientation = 'horizontal'
  end

  -- Extract events from child divs or headings
  for _, block in ipairs(div.content) do
    if block.t == 'Div' and block.classes:includes('event') then
      -- Event as nested div
      local event = extract_event(block)
      if event.date or event.title then
        events:insert(event)
      end
    elseif block.t == 'Header' then
      -- Event as heading (extract date from heading text if formatted as "YYYY: Title")
      local heading_text = pandoc.utils.stringify(block.content)
      local date, title = heading_text:match('^([^:]+):%s*(.+)$')
      if date and title then
        events:insert({
          date = utils.trim(date),
          title = utils.trim(title)
        })
      else
        events:insert({
          date = '',
          title = heading_text
        })
      end
    end
  end

  -- Build events array for Typst
  local event_items = {}
  for _, event in ipairs(events) do
    local event_parts = {}

    local date_value = event.date or ''
    local title_value = event.title or ''
    table.insert(event_parts, string.format('date: "%s"', typst_utils.escape_attribute_value(date_value)))
    table.insert(event_parts, string.format('title: "%s"', typst_utils.escape_attribute_value(title_value)))

    if event.description and event.description ~= '' then
      table.insert(event_parts, string.format('description: "%s"', typst_utils.escape_attribute_value(event.description)))
    end

    table.insert(event_items, '(' .. table.concat(event_parts, ', ') .. ')')
  end

  -- Determine function name based on orientation
  local function_name = orientation == 'horizontal' and 'mcanouil-horizontal-timeline' or 'mcanouil-timeline'

  -- Build Typst code
  local typst_code = string.format(
    '#%s(\n  (%s)\n)',
    function_name,
    table.concat(event_items, ',\n    ')
  )

  return pandoc.RawBlock('typst', typst_code)
end

-- ============================================================================
-- MODULE EXPORTS
-- ============================================================================

return {
  extract_event = extract_event,
  process_div = process_div
}
