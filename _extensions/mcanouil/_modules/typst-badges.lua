--- @module typst-badges
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Handles badge spans for visual indicators
--- @description Mirrors partials/badges.typ

-- ============================================================================
-- MODULE IMPORTS
-- ============================================================================

local wrapper = require(
  quarto.utils.resolve_path('../_modules/typst-wrapper.lua'):gsub('%.lua$', '')
)
local utils = require(
  quarto.utils.resolve_path('../_modules/utils.lua'):gsub('%.lua$', '')
)

-- ============================================================================
-- COMPONENT PROCESSING
-- ============================================================================

--- Process badge span elements
--- Badges are inline elements with text content and optional attributes
--- @param span pandoc.Span Span element
--- @param config table Component configuration with wrapper and arguments fields
--- @return pandoc.RawInline Typst code inline
local function process_span(span, config)
  -- Convert content to plain text
  local content = utils.stringify(span.content)

  -- Convert attributes to table
  local attrs = wrapper.attributes_to_table(span)

  -- Always pass attributes if any exist
  -- config.arguments forces passing even when empty
  local has_attributes = next(attrs) ~= nil
  local should_pass = config.arguments or has_attributes

  -- Build function call using wrapper name
  local typst_code = wrapper.build_function_call(
    config.wrapper,
    content,
    attrs,
    should_pass
  )

  return pandoc.RawInline('typst', typst_code)
end

-- ============================================================================
-- MODULE EXPORTS
-- ============================================================================

return {
  process_span = process_span
}
