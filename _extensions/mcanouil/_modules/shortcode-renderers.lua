--[[
# MIT License
#
# Copyright (c) 2026 Mickaël Canouil
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
]]

--- @module shortcode-renderers
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Shared shortcode renderers for HTML-based formats
--- @description Provides parameterised renderer functions for shortcode components.

-- ============================================================================
-- MODULE IMPORTS
-- ============================================================================

local html_utils = require(
  quarto.utils.resolve_path('../_modules/html-utils.lua'):gsub('%.lua$', '')
)

local M = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Safely convert value to string.
--- Handles Pandoc MetaValue objects and other types.
---
--- @param val any The value to convert
--- @return string|nil The string value or nil if empty
local function to_string(val)
  if val == nil then return nil end
  if type(val) == 'string' then return val end
  -- Handle Pandoc objects
  if pandoc and pandoc.utils and pandoc.utils.stringify then
    return pandoc.utils.stringify(val)
  end
  return tostring(val)
end

--- Check if a colour value is a custom colour (hex, rgb, hsl, etc.).
--- @param colour string|nil The colour value to check
--- @return boolean True if it's a custom colour
local function is_custom_colour(colour)
  if not colour then return false end
  local str = colour:lower()
  return str:match('^#') or str:match('^rgb') or str:match('^hsl')
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

--- @class ShortcodeConfig
--- @field class_prefix string Extra class prefix (e.g., 'reveal-component ')
--- @field defaults table Format-specific defaults

--- Default configuration for HTML format
M.HTML_CONFIG = {
  class_prefix = '',
  defaults = {
    progress_height = '1.5em'
  }
}

--- Default configuration for Reveal.js format
M.REVEALJS_CONFIG = {
  class_prefix = 'reveal-component ',
  defaults = {
    progress_height = '1.2em'
  }
}

-- ============================================================================
-- SHORTCODE RENDERERS
-- ============================================================================

--- Render a value box component.
--- @param kwargs table Keyword arguments from shortcode
--- @param config ShortcodeConfig|nil Configuration options
--- @return string HTML string for the value box
M.render_value_box = function(kwargs, config)
  config = config or M.HTML_CONFIG
  local class_prefix = config.class_prefix or ''

  local value = to_string(kwargs.value) or '0'
  local unit = to_string(kwargs.unit)
  local label = to_string(kwargs.label) or ''
  local icon = to_string(kwargs.icon)
  local colour = to_string(kwargs.colour) or to_string(kwargs.color) or 'info'

  -- Handle custom colours (hex, rgb, hsl)
  local modifier = html_utils.get_colour_modifier(colour)
  local style_attr = ''
  if is_custom_colour(colour) then
    modifier = 'custom'
    style_attr = string.format(' style="--custom-colour: %s;"', html_utils.escape_attribute(colour))
  elseif not modifier then
    modifier = colour
  end

  local base_class = class_prefix .. html_utils.bem_class('value-box')
  local mod_class = html_utils.bem_class('value-box', nil, modifier)
  local classes = base_class .. ' ' .. mod_class

  -- Build value display
  local value_html = html_utils.bem_span('value-box', 'number', nil, nil, html_utils.escape_html(value))

  -- Add unit if provided
  if unit then
    value_html = value_html .. html_utils.bem_span('value-box', 'unit', nil, nil, html_utils.escape_html(unit))
  end

  -- Add icon if provided
  local icon_html = ''
  if icon then
    local icon_char = html_utils.get_icon(icon)
    icon_html = html_utils.bem_span('value-box', 'icon', nil, { ['aria-hidden'] = 'true' },
      html_utils.escape_html(icon_char))
  end

  -- Build value row
  local value_row_html = html_utils.bem_div('value-box', 'value', nil, nil, value_html .. icon_html)

  -- Build label
  local label_html = html_utils.bem_div('value-box', 'label', nil, nil, html_utils.escape_html(label))

  -- Build wrapper
  local aria_label = label .. ': ' .. value
  if unit then
    aria_label = aria_label .. unit
  end

  return string.format('<div class="%s"%s role="figure" aria-label="%s">%s%s</div>',
    classes,
    style_attr,
    html_utils.escape_attribute(aria_label),
    value_row_html,
    label_html)
end

--- Render a badge component.
--- @param kwargs table Keyword arguments from shortcode
--- @param config ShortcodeConfig|nil Configuration options
--- @return string HTML string for the badge
M.render_badge = function(kwargs, config)
  config = config or M.HTML_CONFIG

  local text = to_string(kwargs.text) or to_string(kwargs[1]) or ''
  local colour = to_string(kwargs.colour) or to_string(kwargs.color) or 'neutral'
  local icon = to_string(kwargs.icon)

  local modifier = html_utils.get_colour_modifier(colour) or colour
  local base_class = html_utils.bem_class('badge')
  local mod_class = html_utils.bem_class('badge', nil, modifier)
  local classes = base_class .. ' ' .. mod_class

  local icon_html = ''
  if icon then
    local icon_char = html_utils.get_icon(icon)
    icon_html = html_utils.bem_span('badge', 'icon', nil, { ['aria-hidden'] = 'true' }, html_utils.escape_html(icon_char)) ..
    ' '
  end

  local text_html = html_utils.bem_span('badge', 'text', nil, nil, html_utils.escape_html(text))

  return string.format('<span class="%s">%s%s</span>', classes, icon_html, text_html)
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return M
