--- Typst Extras - Filter
--- @module "typst-extras"
--- @license MIT License
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Entry filter of typst-extras.
--- @description Reads the `typst-extras` options and runs each module on Typst output.
---   With no option and no markup, the document is left unchanged.

local options_module = require(quarto.utils.resolve_path('_modules/options.lua'):gsub('%.lua$', ''))

--- Modules to run, in order.
--- @type table[]
local modules = {
  require(quarto.utils.resolve_path('_modules/sections.lua'):gsub('%.lua$', '')),
  require(quarto.utils.resolve_path('_modules/list-of.lua'):gsub('%.lua$', '')),
  require(quarto.utils.resolve_path('_modules/math-alt.lua'):gsub('%.lua$', '')),
  require(quarto.utils.resolve_path('_modules/watermark.lua'):gsub('%.lua$', '')),
}

--- Options read from the document metadata.
--- @type table
local options = {}

--- Read the options from the document metadata.
--- @param meta pandoc.Meta
--- @return pandoc.Meta
local function read_options(meta)
  options = options_module.read(meta)
  return meta
end

--- Run the modules on the document.
--- Modules that set `all_formats` also run outside Typst output.
--- The Typst check sits here so that it runs per render, not at load time.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function process_document(doc)
  local is_typst = quarto.doc.is_format('typst')
  for _, module in ipairs(modules) do
    if is_typst or module.all_formats then
      doc = module.apply(doc, options)
    end
  end
  return doc
end

return {
  { Meta = read_options },
  { Pandoc = process_document }
}
