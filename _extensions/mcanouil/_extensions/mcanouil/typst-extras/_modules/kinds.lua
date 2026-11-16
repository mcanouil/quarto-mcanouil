--- Typst Extras - Float kinds
--- @module "kinds"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Name the float kinds of a document, and write lists of kinds for Typst.
--- @description Holds the built-in float kinds and the prefix of their Typst figure kind.
---   Reads `crossref.custom` from the metadata, because Quarto's `crossref` Lua global is not set after Quarto's filters.

local emit = require(quarto.utils.resolve_path('_modules/emit.lua'):gsub('%.lua$', ''))

local M = {}

--- Prefix of the Typst figure kind of every Quarto float, as in `quarto-float-fig`.
M.FLOAT_PREFIX = 'quarto-float-'

--- Built-in float kinds, in Quarto's order.
--- @type string[]
M.BUILTIN = { 'fig', 'tbl', 'lst' }

--- Write a Typst array of strings, such as `("quarto-float-fig",)`.
--- @param kinds string[]
--- @return string
function M.typst_array(kinds)
  local quoted = {}
  for _, kind in ipairs(kinds) do
    quoted[#quoted + 1] = emit.string(kind)
  end
  return '(' .. table.concat(quoted, ', ') .. ',)'
end

--- Collect the custom kinds declared in `crossref.custom`.
--- @param meta pandoc.Meta The document metadata
--- @return table<string, string> Map of kind name to its title
function M.custom(meta)
  local kinds = {}
  local crossref = meta.crossref
  if pandoc.utils.type(crossref) ~= 'table' or crossref.custom == nil then
    return kinds
  end
  for _, entry in ipairs(crossref.custom) do
    if entry.key ~= nil then
      local name = pandoc.utils.stringify(entry.key)
      local description = entry['latex-list-of-description']
      kinds[name] = description and pandoc.utils.stringify(description) or name
    end
  end
  return kinds
end

return M
