--- @module "schema-filter"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
---
--- Checks the document configuration under `extensions.codefrag` against the
--- extension schema. The rest of the extension is a Reveal.js plugin that runs
--- in the browser, so this is the only place a fault in the configuration is
--- seen while the document is built.

--- Extension name constant
local EXTENSION_NAME = 'codefrag'

--- Load modules
local schema = require(quarto.utils.resolve_path('_vendor/quarto-wizard/schema.lua'):gsub('%.lua$', ''))
local check = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/schema-check.lua'):gsub('%.lua$', ''))

--- The schema check, built once and used once per document. It reads
--- `_schema.yml` on the way in, and checks the document configuration once.
---
--- The validator is injected rather than required by the check module, so the
--- two vendored sources stay independent of where the other was placed.
---
--- The extension contributes a Reveal.js plugin and no shortcode, so there is
--- no call to check and nothing else for this filter to do. It runs from a
--- `Meta` handler that leaves the metadata unchanged.
---
--- A schema that cannot be read is reported by the module as an error and the
--- render carries on: a configuration file must not stop a document.
local checker = check.new(schema, EXTENSION_NAME)

--- Check the document configuration against the extension schema.
--- The metadata is returned unchanged: this pass reports only.
--- @param meta pandoc.Meta The document metadata
--- @return pandoc.Meta The metadata, unchanged
local function check_options(meta)
  checker:options(meta)
  return meta
end

--- Module export table.
--- Defines the single pass Quarto runs for this filter.
--- @type table
return {
  { Meta = check_options }
}
