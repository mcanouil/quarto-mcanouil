--- @module "typst-badges"
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
local str = require(
  quarto.utils.resolve_path('../_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', '')
)

-- ============================================================================
-- COMPONENT PROCESSING
-- ============================================================================

--- Process badge span elements
--- Badges are inline elements with text content and optional attributes
--- @param span pandoc.Span Span element
--- @param config table Component configuration with wrapper and arguments fields
--- @param written table|nil Schema-resolved attributes the document wrote
--- @return pandoc.RawInline Typst code inline
local function process_badge(span, config, written)
  -- Convert content to plain text
  local content = str.stringify(span.content)

  -- Convert attributes to table
  local attrs = wrapper.attributes_to_table(span)
  for key, value in pairs(written or {}) do
    attrs[key] = value
  end
  -- The schema resolves `color` into its declared name `colour` (and picks
  -- `colour` when the document writes both), but the raw attribute table
  -- above still carries the alias verbatim. `render-badge`
  -- (typst/partials/libs/badges.typ:120) declares only `colour`, with no
  -- `..rest` to absorb an extra named argument, so a `color:` argument
  -- alongside `colour:` fails the whole Typst compile rather than being
  -- ignored. Drop the raw alias once the declared name has a resolved value.
  if written and written.colour ~= nil then
    attrs.color = nil
  end

  -- Always pass attributes if any exist
  -- config.arguments forces passing even when empty
  local has_attributes = next(attrs) ~= nil
  local include_attributes = config.arguments or has_attributes

  -- Build function call using wrapper name
  local typst_code = wrapper.build_function_call(
    config.wrapper,
    content,
    attrs,
    include_attributes
  )

  return pandoc.RawInline('typst', typst_code)
end

-- ============================================================================
-- MODULE EXPORTS
-- ============================================================================

return {
  process_badge = process_badge
}
