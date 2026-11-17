--- Typst Extras - Emit
--- @module "emit"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Add Typst text to the output document.
--- @description Includes the Typst library once per render, and adds header and before-body text.

local M = {}

--- Path of the Typst library, relative to the extension directory.
local LIBRARY_PATH = 'typst-extras.typ'

--- Whether the library is already included in this render.
local library_included = false

--- Include the Typst library in the document header, at most once per render.
function M.library()
  if library_included then
    return
  end
  library_included = true
  quarto.doc.include_file('in-header', LIBRARY_PATH)
end

--- Add Typst text to the document header.
--- @param text string Typst source
function M.header(text)
  quarto.doc.include_text('in-header', text)
end

--- Add Typst text before the document body.
--- @param text string Typst source
function M.before_body(text)
  quarto.doc.include_text('before-body', text)
end

--- Return a Typst string literal for a Lua string.
--- Backslashes, double quotes and newlines are escaped.
--- @param s string The raw text
--- @return string
function M.string(s)
  local escaped = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
  return '"' .. escaped .. '"'
end

return M
