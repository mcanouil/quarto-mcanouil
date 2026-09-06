--- @module "badge"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Format-agnostic badge shortcode
--- @description Provides {{< badge >}} shortcode for rendering inline badges
--- for HTML and Reveal.js formats. Returns Null for Typst (badges use span syntax).

-- ============================================================================
-- MODULE IMPORTS
-- ============================================================================

local format_utils = require(
  quarto.utils.resolve_path('../_modules/format-utils.lua'):gsub('%.lua$', '')
)
local shortcode_renderers = require(
  quarto.utils.resolve_path('../_modules/shortcode-renderers.lua'):gsub('%.lua$', '')
)
local schema = require(
  quarto.utils.resolve_path('../_vendor/quarto-wizard/schema.lua'):gsub('%.lua$', '')
)
local schema_check = require(
  quarto.utils.resolve_path('../_vendor/quarto-lua-modules/schema-check.lua'):gsub('%.lua$', '')
)

-- ============================================================================
-- SCHEMA CHECK
-- ============================================================================

--- The check for this shortcode, built once for the render. It reads
--- `_schema.yml` on the way in, so it belongs at file scope: a check built
--- inside the handler would read the schema again for every call in the
--- document.
---
--- The schema path is given because the check module resolves it against the
--- directory of the entry point that is running, and this file sits one
--- directory below the schema.
---
--- The check reports and changes nothing, so an attribute the schema does not
--- accept is named and still reaches the renderer below.
local checker = schema_check.new(schema, 'mcanouil', '../_schema.yml')

-- ============================================================================
-- SHORTCODE HANDLER
-- ============================================================================

--- @type table<string, function> Shortcode handlers
return {
  ['badge'] = function(args, kwargs, _meta)
    checker:call('badge', args, kwargs)

    local format = format_utils.get_format()

    if format == 'html' or format == 'revealjs' then
      -- HTML-based rendering
      local config = format_utils.get_config()
      return pandoc.RawInline('html', shortcode_renderers.render_badge(kwargs, config))
    end

    -- Typst uses [text]{.badge} span syntax, not a shortcode
    return pandoc.Null()
  end
}
