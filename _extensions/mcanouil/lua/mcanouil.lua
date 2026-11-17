--- @module "mcanouil"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Entry filter of the mcanouil extension
--- @description Returns the list of filter steps. Later steps are added by
--- requiring their module and appending it to STEPS.

local preset = require(quarto.utils.resolve_path('preset.lua'):gsub('%.lua$', ''))
local contrast = require(quarto.utils.resolve_path('contrast.lua'):gsub('%.lua$', ''))
local labels = require(quarto.utils.resolve_path('lib/labels.lua'):gsub('%.lua$', ''))
local document = require(quarto.utils.resolve_path('document.lua'):gsub('%.lua$', ''))

--- @type table[] The filter steps, run in order.
local STEPS = {
  contrast.filter,
  preset.filter,
  labels.filter,
  document.filter,
}

return STEPS
