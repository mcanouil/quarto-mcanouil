--- @module "mcanouil-final"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Last filter of the mcanouil extension
--- @description Returns the list of filter steps that run after typst-extras,
--- so they see the equation calls that typst-extras writes.

local typst_elements = require(quarto.utils.resolve_path('typst-elements.lua'):gsub('%.lua$', ''))

--- @type table[] The filter steps, run in order.
local STEPS = {
  typst_elements.post_filter,
}

return STEPS
