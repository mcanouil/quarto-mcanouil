--- @module "mcanouil-post"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Closing filter of the mcanouil extension
--- @description Returns the list of filter steps that run after the embedded tools.
--- Later steps are added by requiring their module and appending it to STEPS.

local authors = require(quarto.utils.resolve_path('authors.lua'):gsub('%.lua$', ''))
local sections = require(quarto.utils.resolve_path('sections.lua'):gsub('%.lua$', ''))

--- @type table[] The filter steps, run in order.
local STEPS = {
  sections.filter,
  authors.post_filter,
}

return STEPS
