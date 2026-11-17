--- Typst Extras - Watermark
--- @module "watermark"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Draw a text or image watermark on every page.
--- @description Turns the `watermark` option into a `set page(foreground: ..)` rule that calls `typst-extras-watermark`.
---   The foreground is used so that Quarto's logo, which sits in the page background, is kept.

local options = require(quarto.utils.resolve_path('_modules/options.lua'):gsub('%.lua$', ''))
local emit = require(quarto.utils.resolve_path('_modules/emit.lua'):gsub('%.lua$', ''))

local M = {}

--- Name used in messages.
local MODULE_NAME = 'watermark'

--- Accepted values of `position`, with the Typst alignment of each.
--- @type table<string, string>
local POSITIONS = {
  ['center'] = 'center + horizon',
  ['top'] = 'top',
  ['bottom'] = 'bottom',
  ['left'] = 'left',
  ['right'] = 'right',
  ['top-left'] = 'top + left',
  ['top-right'] = 'top + right',
  ['bottom-left'] = 'bottom + left',
  ['bottom-right'] = 'bottom + right',
}

--- Position names in the order shown in messages.
local POSITION_NAMES = {
  'center', 'top', 'bottom', 'left', 'right', 'top-left', 'top-right', 'bottom-left', 'bottom-right',
}

--- Typst colour names that can be written without a function call.
--- @type table<string, boolean>
local COLOUR_NAMES = {}
for name in ([[black gray silver white navy blue aqua teal eastern purple fuchsia maroon red orange yellow
  olive green lime]]):gmatch('%a+') do
  COLOUR_NAMES[name] = true
end

--- Keys accepted in the map form, in the order shown in messages.
local KNOWN_KEYS = { 'text', 'image', 'opacity', 'angle', 'size', 'colour', 'position', 'width' }

--- Patterns that a Typst number with a unit must match.
local NUMBER = '%-?%d+%.?%d*'

--- Patterns of the lengths accepted for `size`.
local LENGTHS = { NUMBER .. 'pt', NUMBER .. 'mm', NUMBER .. 'cm', NUMBER .. 'in', NUMBER .. 'em' }

--- Check that a value is a string matching one of the patterns, and stop the render when it is not.
--- @param key string The option name
--- @param value any The value
--- @param patterns string[] Lua patterns, any of which accepts the value
--- @param expected string What to write, for the message
local function require_pattern(key, value, patterns, expected)
  if type(value) == 'string' then
    for _, pattern in ipairs(patterns) do
      if value:match('^' .. pattern .. '$') then
        return
      end
    end
  end
  options.fail(MODULE_NAME, 'unsupported ' .. key .. ' ' .. tostring(value) .. '. Use ' .. expected .. '.')
end

--- Convert the `colour` option into a Typst colour expression.
--- @param value any The option value
--- @return string
local function colour_expression(value)
  if type(value) == 'string' and COLOUR_NAMES[value] then
    return value
  end
  if type(value) == 'string' and (value:match('^#%x%x%x$') or value:match('^#%x%x%x%x%x%x$')
      or value:match('^#%x%x%x%x%x%x%x%x$')) then
    return 'rgb(' .. emit.string(value) .. ')'
  end
  options.fail(MODULE_NAME, 'unsupported colour ' .. tostring(value) ..
    '. Use a Typst colour name such as gray or red, or a hex colour such as "#cc0000".')
end

--- Normalise the option into a map.
--- @param option any The value of `watermark`
--- @return table
local function parse(option)
  if type(option) == 'string' then
    return { text = option }
  end
  if type(option) ~= 'table' or #option > 0 then
    options.fail(MODULE_NAME, 'unsupported value. Use a string, or a map with text or image.')
  end
  options.check_keys(MODULE_NAME, option, KNOWN_KEYS)
  return option
end

--- Build the argument list of `typst-extras-watermark`.
--- Stops the render when a value is not valid.
--- @param map table The normalised option
--- @return string
local function arguments(map)
  local has_text = map.text ~= nil
  local has_image = map.image ~= nil
  if has_text and has_image then
    options.fail(MODULE_NAME, 'set text or image, not both.')
  end
  if not has_text and not has_image then
    options.fail(MODULE_NAME, 'set text or image.')
  end
  if has_image and map.opacity ~= nil then
    options.fail(MODULE_NAME, 'opacity does not apply to an image. Fade the image file instead.')
  end
  local parts = {}
  local source = has_text and 'text' or 'image'
  if type(map[source]) ~= 'string' or map[source] == '' then
    options.fail(MODULE_NAME, source .. ' must be a non-empty string.')
  end
  parts[#parts + 1] = source .. ': ' .. emit.string(map[source])
  if map.opacity ~= nil then
    require_pattern('opacity', map.opacity, { NUMBER .. '%%' }, 'a percentage such as 15%')
    local percent = tonumber(map.opacity:sub(1, -2))
    if percent < 0 or percent > 100 then
      options.fail(MODULE_NAME, 'unsupported opacity ' .. map.opacity .. '. Use a percentage from 0% to 100%.')
    end
    parts[#parts + 1] = 'opacity: ' .. map.opacity
  end
  if map.angle ~= nil then
    require_pattern('angle', map.angle, { NUMBER .. 'deg', NUMBER .. 'rad' }, 'an angle such as -45deg')
    parts[#parts + 1] = 'angle: ' .. map.angle
  end
  if map.size ~= nil then
    require_pattern('size', map.size, LENGTHS, 'a length in pt, mm, cm, in or em, such as 4em or 48pt')
    parts[#parts + 1] = 'size: ' .. map.size
  end
  if map.colour ~= nil then
    parts[#parts + 1] = 'colour: ' .. colour_expression(map.colour)
  end
  if map.position ~= nil then
    local alignment = type(map.position) == 'string' and POSITIONS[map.position]
    if not alignment then
      options.fail(MODULE_NAME, 'unsupported position ' .. tostring(map.position) .. '. Use one of: ' ..
        table.concat(POSITION_NAMES, ', ') .. '.')
    end
    parts[#parts + 1] = 'position: ' .. alignment
  end
  if map.width ~= nil then
    local widths = { NUMBER .. '%%', table.unpack(LENGTHS) }
    require_pattern('width', map.width, widths, 'a percentage, or a length in pt, mm, cm, in or em, such as 50% or 8cm')
    parts[#parts + 1] = 'width: ' .. map.width
  end
  return table.concat(parts, ', ')
end

--- Add the watermark to the document.
--- @param doc pandoc.Pandoc The document
--- @param config table The normalised `typst-extras` options
--- @return pandoc.Pandoc
function M.apply(doc, config)
  local option = config.watermark
  if option == nil or option == false then
    return doc
  end
  local args = arguments(parse(option))
  emit.library()
  emit.header('#set page(foreground: typst-extras-watermark(' .. args .. '))\n')
  return doc
end

return M
