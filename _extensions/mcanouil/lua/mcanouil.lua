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
local authors = require(quarto.utils.resolve_path('authors.lua'):gsub('%.lua$', ''))
local logo = require(quarto.utils.resolve_path('logo.lua'):gsub('%.lua$', ''))
local alt_text = require(quarto.utils.resolve_path('alt-text.lua'):gsub('%.lua$', ''))
local math_alt_text = require(quarto.utils.resolve_path('math-alt-text.lua'):gsub('%.lua$', ''))
local sections = require(quarto.utils.resolve_path('sections.lua'):gsub('%.lua$', ''))
local quote = require(quarto.utils.resolve_path('quote.lua'):gsub('%.lua$', ''))
local html_page = require(quarto.utils.resolve_path('html-page.lua'):gsub('%.lua$', ''))
local deck = require(quarto.utils.resolve_path('deck.lua'):gsub('%.lua$', ''))

--- @type table[] The filter steps, run in order.
local STEPS = {
  contrast.filter,
  preset.filter,
  labels.filter,
  document.filter,
  authors.filter,
  logo.filter,
  alt_text.filter,
  math_alt_text.filter,
  sections.pre_filter,
  quote.filter,
  html_page.filter,
  deck.filter,
}

return STEPS
