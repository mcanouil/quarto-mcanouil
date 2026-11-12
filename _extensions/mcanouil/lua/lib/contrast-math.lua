--- @module "contrast-math"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief WCAG relative luminance and contrast ratio
--- @description Pure functions over hex colours, with no Pandoc or Quarto dependency.

--- @type string Directory of the extension, the parent of `lua/`.
local fail = require('lib.fail')
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\]lib[/\\][^/\\]+$')

local colour = dofile(EXTENSION_DIR .. '/_vendor/quarto-lua-modules/colour.lua')

local M = {}

--- Linearise one sRGB channel.
--- @param channel number Channel from 0 to 255
--- @return number Linear channel from 0 to 1
local function linear(channel)
  local value = channel / 255
  if value <= 0.04045 then
    return value / 12.92
  end
  return ((value + 0.055) / 1.055) ^ 2.4
end

--- Compute the WCAG relative luminance of a colour.
--- @param hex string Hex colour, three or six digits
--- @return number Luminance from 0 to 1
function M.luminance(hex)
  local full = colour.to_html(hex:lower(), 'hex')
  local red, green, blue = full:match('^#(%x%x)(%x%x)(%x%x)$')
  if not red then
    fail.stop('mcanouil: cannot read the hex colour "' .. tostring(hex) .. '" for the contrast check.')
  end
  return 0.2126 * linear(tonumber(red, 16))
    + 0.7152 * linear(tonumber(green, 16))
    + 0.0722 * linear(tonumber(blue, 16))
end

--- Compute the WCAG contrast ratio of two colours, the same either way round.
--- @param fg string Hex colour
--- @param bg string Hex colour
--- @return number Ratio from 1 to 21
function M.ratio(fg, bg)
  local first, second = M.luminance(fg), M.luminance(bg)
  if first < second then
    first, second = second, first
  end
  return (first + 0.05) / (second + 0.05)
end

return M
