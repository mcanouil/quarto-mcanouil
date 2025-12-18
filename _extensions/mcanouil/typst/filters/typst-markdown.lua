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

--- @module typst-markdown
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Minimal orchestrator for markdown to Typst function translation
--- @description Delegates component processing to dedicated modules

-- ============================================================================
-- MODULE IMPORTS
-- ============================================================================

local config_module = require(
  quarto.utils.resolve_path('../_modules/config.lua'):gsub('%.lua$', '')
)
local badges = require(
  quarto.utils.resolve_path('../_modules/badges.lua'):gsub('%.lua$', '')
)
local card_grid = require(
  quarto.utils.resolve_path('../_modules/card-grid.lua'):gsub('%.lua$', '')
)
local timeline = require(
  quarto.utils.resolve_path('../_modules/timeline.lua'):gsub('%.lua$', '')
)
local wrapper = require(
  quarto.utils.resolve_path('../_modules/wrapper.lua'):gsub('%.lua$', '')
)

-- ============================================================================
-- GLOBAL CONFIGURATION
-- ============================================================================

--- @type table<string, table> Div mappings (loaded from configuration)
local DIV_MAPPINGS = {}

--- @type table<string, table> Span mappings (loaded from configuration)
local SPAN_MAPPINGS = {}

--- @type table<string, table> Table mappings (loaded from configuration, reserved for future use)
local TABLE_MAPPINGS = {}

--- @type table<string, table> Image mappings (loaded from configuration, reserved for future use)
local IMAGE_MAPPINGS = {}

-- ============================================================================
-- COMPONENT REGISTRY
-- ============================================================================

--- Component registry mapping class names to handler functions
--- @type table<string, function>
local DIV_HANDLERS = {
  ['value-box'] = wrapper.create_atomic_handler(),
  ['panel'] = wrapper.create_wrapped_handler(true),
  ['progress'] = wrapper.create_atomic_handler(),
  ['divider'] = wrapper.create_wrapped_handler(false),
  ['executive-summary'] = wrapper.create_wrapped_handler(true),
  ['card-grid'] = card_grid.process_div,
  ['timeline'] = timeline.process_div,
  ['horizontal-timeline'] = timeline.process_div
}

--- Span handler registry
--- @type table<string, function>
local SPAN_HANDLERS = {
  ['badge'] = badges.process_span
}

-- ============================================================================
-- METADATA PROCESSING
-- ============================================================================

--- Load configuration from document metadata
--- @param meta pandoc.Meta Document metadata
--- @return pandoc.Meta Unchanged metadata
function Meta(meta)
  local builtin = config_module.get_builtin_mappings()
  local user = config_module.load_element_mappings(meta)

  DIV_MAPPINGS = config_module.merge_configurations(builtin.div, user.div)
  SPAN_MAPPINGS = config_module.merge_configurations(builtin.span, user.span)
  TABLE_MAPPINGS = config_module.merge_configurations(builtin.table, user.table)
  IMAGE_MAPPINGS = config_module.merge_configurations(builtin.image, user.image)

  return meta
end

-- ============================================================================
-- ELEMENT TRANSFORMATIONS
-- ============================================================================

--- Process Div elements
--- @param div pandoc.Div Div element to process
--- @return pandoc.RawBlock|table|pandoc.Div Transformed element or original
function Div(div)
  if not quarto.doc.is_format('typst') then
    return div
  end

  -- Check each class against configured mappings
  for _, class in ipairs(div.classes) do
    if DIV_MAPPINGS[class] then
      local config = DIV_MAPPINGS[class]
      local handler = DIV_HANDLERS[class]

      if handler then
        -- Use component-specific handler
        return handler(div, config)
      else
        -- Default handling: wrap content with Typst function
        local attrs = wrapper.attributes_to_table(div)
        local opening, closing = wrapper.build_typst_block_wrappers(config, attrs)

        local result = { pandoc.RawBlock('typst', opening) }
        for _, item in ipairs(div.content) do
          table.insert(result, item)
        end
        table.insert(result, pandoc.RawBlock('typst', closing))

        return result
      end
    end
  end

  return div
end

--- Process Span elements
--- @param span pandoc.Span Span element to process
--- @return pandoc.RawInline|pandoc.Span Transformed element or original
function Span(span)
  if not quarto.doc.is_format('typst') then
    return span
  end

  for _, class in ipairs(span.classes) do
    if SPAN_MAPPINGS[class] then
      local config = SPAN_MAPPINGS[class]
      local handler = SPAN_HANDLERS[class]

      if handler then
        return handler(span, config)
      else
        -- Default handling: wrap content with Typst function
        local content = pandoc.write(pandoc.Pandoc({ pandoc.Plain(span.content) }), 'typst')
        local attrs = wrapper.attributes_to_table(span)
        local has_attributes = next(attrs) ~= nil
        local should_pass = config.arguments or has_attributes
        local typst_code = wrapper.build_function_call(config.wrapper, content, attrs, should_pass)
        return pandoc.RawInline('typst', typst_code)
      end
    end
  end

  return span
end

--- Process Table elements (placeholder for future customisation)
--- @param tbl pandoc.Table Table element to process
--- @return pandoc.Table Original table (no transformation applied yet)
function Table(tbl)
  if not quarto.doc.is_format('typst') then
    return tbl
  end

  -- Placeholder for future table customisation
  -- TABLE_MAPPINGS can be used here when implemented
  return tbl
end

--- Process Image elements (placeholder for future customisation)
--- @param img pandoc.Image Image element to process
--- @return pandoc.Image Original image (no transformation applied yet)
function Image(img)
  if not quarto.doc.is_format('typst') then
    return img
  end

  -- Placeholder for future image customisation
  -- IMAGE_MAPPINGS can be used here when implemented
  return img
end

-- ============================================================================
-- FILTER EXPORTS
-- ============================================================================

return {
  { Meta = Meta },
  { Div = Div, Span = Span, Table = Table, Image = Image }
}
