--- @module "labels"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Label lookup with an English fallback, and delivery to Typst
--- @description Reads the labels of the document language from Quarto's language
--- table. A key that the table lacks falls back to the English value of
--- `_language.yml`. The label text lives only in the language files.

--- @type string Directory of the extension, the parent of `lua/`.
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\]lib[/\\][^/\\]+$')

--- @type string File of the English labels, which are also the fallback.
local ENGLISH_FILE = '_language.yml'

--- @type table<string, string>|nil English labels, read on first use.
local english = nil

local M = {}

--- Read a language file of the extension.
--- @param filename string File name in the extension directory, for example `_language.yml`
--- @return table<string, string> Label of each key
function M.read(filename)
  local path = EXTENSION_DIR .. '/' .. filename
  local file = io.open(path, 'r')
  if not file then
    error('mcanouil: cannot open the language file ' .. path .. '.')
  end
  local text = file:read('a')
  file:close()
  local meta = pandoc.read('---\n' .. text .. '\n---\n', 'markdown-smart').meta
  local labels = {}
  for key, value in pairs(meta) do
    labels[key] = pandoc.utils.stringify(value)
  end
  return labels
end

--- Answer the English labels.
--- @return table<string, string> Label of each key
local function english_labels()
  if english == nil then
    english = M.read(ENGLISH_FILE)
  end
  return english
end

--- Answer the label of a key from a language table, or the English one.
--- @param key string Label key, for example `mcanouil-exercise`
--- @param language table<string, any> Language table of the document
--- @return string Label
function M.lookup(key, language)
  local value = language[key]
  if value ~= nil then
    return pandoc.utils.stringify(value)
  end
  local fallback = english_labels()[key]
  if fallback == nil then
    error(string.format('mcanouil: unknown label "%s"; add it to %s and the other language files.', key, ENGLISH_FILE))
  end
  return fallback
end

--- Answer the label of a key in the language of the document.
--- @param key string Label key, for example `mcanouil-exercise`
--- @return string Label
function M.get(key)
  return M.lookup(key, quarto.doc.language or {})
end

--- Format text as a Typst string literal.
--- @param text string Text
--- @return string Literal, with quotes and backslashes escaped
function M.typst_string(text)
  return '"' .. text:gsub('[\\"]', '\\%0') .. '"'
end

--- Deliver every label to Typst as the `mcanouil-labels` dictionary.
--- Each value is a Typst string literal, so the template can use it as text.
--- @param meta table Document metadata
--- @return table Metadata
local function deliver(meta)
  if not quarto.doc.is_format('typst') then
    return meta
  end
  local delivered = {}
  for key in pairs(english_labels()) do
    delivered[key] = pandoc.MetaInlines({ pandoc.RawInline('typst', M.typst_string(M.get(key))) })
  end
  meta['mcanouil-labels'] = delivered
  return meta
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = deliver }

return M
