--- Typst Extras - Options
--- @module "options"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Read and report on the `typst-extras` option block.
--- @description Normalises the `extensions.typst-extras` metadata block into plain Lua values, and reports problems with a common prefix.

local log = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))

local M = {}

--- Extension name constant
local EXTENSION_NAME = 'typst-extras'

--- Keys accepted in the `extensions.typst-extras` block, in the order shown in messages.
local KNOWN_KEYS = { 'list-of', 'watermark', 'sections' }

--- Metatable that marks the arrays made from metadata lists, so that an empty list differs from an empty map.
local LIST = {}

--- Convert a metadata value into a plain Lua value.
--- Maps become tables, lists become arrays, booleans stay booleans, everything else becomes a string.
--- @param value any A pandoc metadata value
--- @return any
local function normalise(value)
  local kind = pandoc.utils.type(value)
  if kind == 'boolean' then
    return value
  elseif kind == 'Inlines' or kind == 'Blocks' then
    return pandoc.utils.stringify(value)
  elseif kind == 'List' then
    local items = setmetatable({}, LIST)
    for _, item in ipairs(value) do
      items[#items + 1] = normalise(item)
    end
    return items
  elseif kind == 'table' then
    local map = {}
    for key, item in pairs(value) do
      map[key] = normalise(item)
    end
    return map
  end
  return pandoc.utils.stringify(value)
end

--- Tell whether a normalised value comes from a metadata list.
--- @param value any A value returned by `M.read`
--- @return boolean
function M.is_list(value)
  return type(value) == 'table' and getmetatable(value) == LIST
end

--- Stop the render with a prefixed error message.
--- Quarto replaces the global `error` in filters with a function that only logs,
--- so `assert` raises the error that stops the render.
--- @param module string The name of the module that failed
--- @param message string What went wrong and how to fix it
function M.fail(module, message)
  assert(false, '[' .. EXTENSION_NAME .. '] ' .. module .. ': ' .. message)
end

--- Stop the render when a map has a key that is not known.
--- @param module string The name of the module that reads the map
--- @param map table The normalised map
--- @param known string[] The known keys, in the order shown in the message
function M.check_keys(module, map, known)
  local accepted = {}
  for _, key in ipairs(known) do
    accepted[key] = true
  end
  for key in pairs(map) do
    if not accepted[key] then
      M.fail(module, 'unknown key ' .. tostring(key) .. '. Known keys: ' .. table.concat(known, ', ') .. '.')
    end
  end
end

--- Read the `extensions.typst-extras` block of the document metadata.
--- A top-level `typst-extras` block is ignored, with a warning.
--- Stops the render when the block has a key that is not known.
--- @param meta pandoc.Meta The document metadata
--- @return table The normalised block, or an empty table when absent
function M.read(meta)
  if meta[EXTENSION_NAME] ~= nil then
    M.warn('options', 'the top-level typst-extras block is ignored. Move it under extensions: typst-extras:.')
  end
  local block = meta.extensions and meta.extensions[EXTENSION_NAME]
  if block == nil then
    return {}
  end
  local options = normalise(block)
  if type(options) ~= 'table' or M.is_list(options) then
    M.fail('options', 'extensions.typst-extras must be a map. Known keys: ' .. table.concat(KNOWN_KEYS, ', ') .. '.')
  end
  M.check_keys('options', options, KNOWN_KEYS)
  return options
end

--- Log a prefixed warning message.
--- @param module string The name of the module that warns
--- @param message string What the reader should know
function M.warn(module, message)
  log.log_warning(EXTENSION_NAME, module .. ': ' .. message)
end

return M
