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

--- @module html-utils
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief HTML-specific utility functions for component rendering
--- @description Provides value conversion, escaping, and element generation for HTML output.

local M = {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

--- @type string BEM prefix for component classes
M.BEM_PREFIX = 'mc'

--- @type table<string, string> Colour name mappings to CSS class modifiers
M.COLOUR_CLASSES = {
  info = 'info',
  success = 'success',
  warning = 'warning',
  danger = 'danger',
  caution = 'caution',
  neutral = 'neutral',
  subtle = 'subtle',
  emphasis = 'emphasis',
  accent = 'accent',
  outline = 'outline'
}

--- @type table<string, string> Icon shortcut mappings
M.ICON_SHORTCUTS = {
  up = '↑',
  down = '↓',
  stable = '—'
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Escape special HTML characters in text.
--- Escapes &, <, >, ", and ' to prevent XSS and ensure valid HTML.
---
--- @param text string The text to escape
--- @return string Escaped text safe for use in HTML
--- @usage local escaped = M.escape_html('Hello <World>')
M.escape_html = function(text)
  if text == nil then return '' end
  if type(text) ~= 'string' then text = tostring(text) end
  local result = text
    :gsub('&', '&amp;')
    :gsub('<', '&lt;')
    :gsub('>', '&gt;')
    :gsub('"', '&quot;')
    :gsub("'", '&#39;')
  return result
end

--- Escape special HTML attribute characters.
--- Escapes characters that could break attribute values.
---
--- @param value string The attribute value to escape
--- @return string Escaped value safe for use in HTML attributes
--- @usage local escaped = M.escape_attribute('Hello "World"')
M.escape_attribute = function(value)
  if value == nil then return '' end
  if type(value) ~= 'string' then value = tostring(value) end
  local result = value
    :gsub('&', '&amp;')
    :gsub('"', '&quot;')
    :gsub('<', '&lt;')
    :gsub('>', '&gt;')
  return result
end

--- Build HTML attribute string from a table of key-value pairs.
--- Handles boolean attributes (true = present, false = omitted).
---
--- @param attrs table<string, any> Attribute key-value pairs
--- @return string Space-prefixed attribute string (e.g., ' class="foo" id="bar"')
--- @usage local attr_str = M.build_attributes({class = 'panel', id = 'main'})
M.build_attributes = function(attrs)
  if not attrs or next(attrs) == nil then
    return ''
  end

  local attr_items = {}
  for key, value in pairs(attrs) do
    if value == true then
      -- Boolean attribute (e.g., disabled, hidden)
      table.insert(attr_items, key)
    elseif value and value ~= false then
      -- Standard attribute
      table.insert(attr_items, string.format('%s="%s"', key, M.escape_attribute(tostring(value))))
    end
  end

  if #attr_items == 0 then
    return ''
  end

  return ' ' .. table.concat(attr_items, ' ')
end

--- Build BEM class name.
--- Constructs a class name following the BEM (Block Element Modifier) convention.
---
--- @param block string The block name (e.g., 'panel')
--- @param element string|nil The element name (e.g., 'header')
--- @param modifier string|nil The modifier name (e.g., 'info')
--- @return string BEM class name (e.g., 'mcanouil-panel__header--info')
--- @usage local cls = M.bem_class('panel', 'header', 'info')
M.bem_class = function(block, element, modifier)
  local class = M.BEM_PREFIX .. '-' .. block
  if element then
    class = class .. '__' .. element
  end
  if modifier then
    class = class .. '--' .. modifier
  end
  return class
end

--- Build multiple BEM class names.
--- Returns space-separated class names for use in class attribute.
---
--- @param block string The block name
--- @param modifiers table|nil Array of modifier names to apply
--- @return string Space-separated class names
--- @usage local cls = M.bem_classes('panel', {'info', 'large'})
M.bem_classes = function(block, modifiers)
  local classes = { M.bem_class(block) }
  if modifiers then
    for _, mod in ipairs(modifiers) do
      if mod and mod ~= '' then
        table.insert(classes, M.bem_class(block, nil, mod))
      end
    end
  end
  return table.concat(classes, ' ')
end

--- Safely convert value to string.
--- Handles Pandoc MetaValue objects and other types.
---
--- @param val any The value to convert
--- @return string|nil The string value or nil if empty
--- @usage local str = M.to_string(kwargs.value)
M.to_string = function(val)
  if not val then return nil end
  if type(val) == 'string' then
    return val ~= '' and val or nil
  end
  -- Handle Pandoc objects
  if pandoc and pandoc.utils and pandoc.utils.stringify then
    local str = pandoc.utils.stringify(val)
    return str ~= '' and str or nil
  end
  local str = tostring(val)
  return str ~= '' and str or nil
end

--- Check if a colour value is a custom colour (hex, rgb, hsl, etc.).
---
--- @param colour string|nil The colour value to check
--- @return boolean True if it's a custom colour
--- @usage local is_custom = M.is_custom_colour('#ff6600') -- returns true
M.is_custom_colour = function(colour)
  if not colour then return false end
  local str = colour:lower()
  return str:match('^#') or str:match('^rgb') or str:match('^hsl')
end

--- Get colour class modifier.
--- Maps colour names to CSS class modifiers.
---
--- @param colour string|nil The colour name (e.g., 'success', 'warning')
--- @return string|nil The CSS class modifier or nil if not found
--- @usage local mod = M.get_colour_modifier('success') -- returns 'success'
M.get_colour_modifier = function(colour)
  local str = M.to_string(colour)
  if not str or str == '' then return nil end
  return M.COLOUR_CLASSES[str:lower()]
end

--- Get icon character.
--- Maps icon shortcuts to actual characters.
---
--- @param icon string|nil The icon name or character
--- @return string|nil The icon character or the original value if not a shortcut
--- @usage local char = M.get_icon('up') -- returns '↑'
--- @usage local char = M.get_icon('✓') -- returns '✓'
M.get_icon = function(icon)
  local str = M.to_string(icon)
  if not str or str == '' then return nil end
  return M.ICON_SHORTCUTS[str:lower()] or str
end

--- Build an HTML element.
--- Constructs a complete HTML element with tag, attributes, and content.
---
--- @param tag string The HTML tag name (e.g., 'div', 'span')
--- @param attrs table|nil Attribute key-value pairs
--- @param content string|nil The inner content (can include nested HTML)
--- @param self_closing boolean|nil If true, generates self-closing tag (e.g., <hr />)
--- @return string Complete HTML element string
--- @usage local html = M.element('div', {class = 'panel'}, 'Content')
M.element = function(tag, attrs, content, self_closing)
  local attr_str = M.build_attributes(attrs or {})
  if self_closing then
    return string.format('<%s%s />', tag, attr_str)
  elseif content then
    return string.format('<%s%s>%s</%s>', tag, attr_str, content, tag)
  else
    return string.format('<%s%s></%s>', tag, attr_str, tag)
  end
end

--- Build a div element with BEM classes.
--- Convenience function for building component div elements.
---
--- @param block string The BEM block name
--- @param element string|nil The BEM element name
--- @param modifier string|nil The BEM modifier name
--- @param attrs table|nil Additional attributes (merged with class)
--- @param content string|nil The inner content
--- @return string Complete div element string
--- @usage local html = M.bem_div('panel', 'header', 'info', {role = 'banner'}, 'Title')
M.bem_div = function(block, element, modifier, attrs, content)
  local classes = M.bem_class(block, element, modifier)
  local merged_attrs = attrs or {}

  -- Merge class attribute
  if merged_attrs.class then
    merged_attrs.class = classes .. ' ' .. merged_attrs.class
  else
    merged_attrs.class = classes
  end

  return M.element('div', merged_attrs, content)
end

--- Build a span element with BEM classes.
--- Convenience function for building component span elements.
---
--- @param block string The BEM block name
--- @param element string|nil The BEM element name
--- @param modifier string|nil The BEM modifier name
--- @param attrs table|nil Additional attributes (merged with class)
--- @param content string|nil The inner content
--- @return string Complete span element string
--- @usage local html = M.bem_span('badge', nil, 'success', nil, 'Done')
M.bem_span = function(block, element, modifier, attrs, content)
  local classes = M.bem_class(block, element, modifier)
  local merged_attrs = attrs or {}

  -- Merge class attribute
  if merged_attrs.class then
    merged_attrs.class = classes .. ' ' .. merged_attrs.class
  else
    merged_attrs.class = classes
  end

  return M.element('span', merged_attrs, content)
end

-- ============================================================================
-- SHORTCODE UTILITIES
-- ============================================================================

--- Create a shortcode handler for HTML format.
--- Factory function that returns a shortcode handler for a given component.
---
--- @param render_fn function Function that takes (kwargs) and returns HTML string
--- @return function Shortcode handler returning pandoc.RawBlock or pandoc.Null
--- @usage return { ['divider'] = M.create_shortcode_handler(render_divider) }
M.create_shortcode_handler = function(render_fn)
  return function(_args, kwargs, _meta)
    if not quarto.doc.is_format('html') then
      return pandoc.Null()
    end
    local html = render_fn(kwargs)
    return pandoc.RawBlock('html', html)
  end
end

--- Create an inline shortcode handler for HTML format.
--- Factory function for shortcodes that return inline elements.
---
--- @param render_fn function Function that takes (kwargs) and returns HTML string
--- @return function Shortcode handler returning pandoc.RawInline or pandoc.Null
--- @usage return { ['badge'] = M.create_inline_shortcode_handler(render_badge) }
M.create_inline_shortcode_handler = function(render_fn)
  return function(_args, kwargs, _meta)
    if not quarto.doc.is_format('html') then
      return pandoc.Null()
    end
    local html = render_fn(kwargs)
    return pandoc.RawInline('html', html)
  end
end

-- ============================================================================
-- COMPONENT RENDER FUNCTIONS
-- ============================================================================

--- Render a divider component.
--- Generates minimal HTML; CSS handles all visual styling via BEM classes and custom properties.
---
--- @param kwargs table Keyword arguments from shortcode
--- @param config table|nil Configuration with class_prefix and defaults
--- @return string HTML string for the divider
--- @usage local html = M.render_divider({style = 'dashed', width = '80%'}, {class_prefix = ''})
M.render_divider = function(kwargs, config)
  config = config or {}
  local class_prefix = config.class_prefix or ''

  local style = M.to_string(kwargs.style) or 'solid'
  local label = M.to_string(kwargs.label)
  local thickness = M.to_string(kwargs.thickness) or '1pt'
  local width = M.to_string(kwargs.width) or '50%'

  local base_class = class_prefix .. M.bem_class('divider')
  local mod_class = M.bem_class('divider', nil, style)
  local classes = base_class .. ' ' .. mod_class

  local style_attr = string.format('--divider-thickness: %s; --divider-width: %s;', thickness, width)

  if label then
    -- Divider with label
    local label_html = M.bem_span('divider', 'label', nil, nil, M.escape_html(label))
    return string.format('<div class="%s" style="%s" role="separator" aria-label="%s">%s</div>',
      classes, style_attr, M.escape_attribute(label), label_html)
  else
    -- Simple divider
    return string.format('<hr class="%s" style="%s" />',
      classes, style_attr)
  end
end

--- Render a progress bar component.
--- Generates minimal HTML; CSS handles all visual styling via BEM classes and custom properties.
---
--- @param kwargs table Keyword arguments from shortcode
--- @param config table|nil Configuration with class_prefix and defaults
--- @return string HTML string for the progress bar
--- @usage local html = M.render_progress({value = 75, colour = 'success'}, {class_prefix = ''})
M.render_progress = function(kwargs, config)
  config = config or {}
  local class_prefix = config.class_prefix or ''
  local default_height = (config.defaults and config.defaults.progress_height) or '1.5em'

  local value = tonumber(M.to_string(kwargs.value)) or 0
  local label = M.to_string(kwargs.label)
  local colour = M.to_string(kwargs.colour) or M.to_string(kwargs.color) or 'info'
  local show_value = M.to_string(kwargs['show-value']) ~= 'false'
  local height = M.to_string(kwargs.height) or default_height

  -- Handle custom colours (hex, rgb, hsl)
  local modifier = M.get_colour_modifier(colour)
  local custom_colour_style = ''
  if M.is_custom_colour(colour) then
    modifier = 'custom'
    custom_colour_style = string.format(' --custom-colour: %s;', M.escape_attribute(colour))
  elseif not modifier then
    modifier = colour
  end

  local base_class = class_prefix .. M.bem_class('progress')
  local mod_class = M.bem_class('progress', nil, modifier)
  local classes = base_class .. ' ' .. mod_class

  local style_attr = string.format('--progress-height: %s;%s', height, custom_colour_style)

  -- Build inner bar
  local bar_style = string.format('width: %d%%;', math.min(100, math.max(0, value)))
  local bar_content = ''
  if show_value then
    bar_content = string.format('<span class="%s">%d%%</span>',
      M.bem_class('progress', 'value'),
      value)
  end
  local bar_html = string.format('<div class="%s" style="%s" role="progressbar" aria-valuenow="%d" aria-valuemin="0" aria-valuemax="100">%s</div>',
    M.bem_class('progress', 'bar'),
    bar_style,
    value,
    bar_content)

  -- Build wrapper
  local wrapper_html = string.format('<div class="%s" style="%s">%s</div>',
    classes, style_attr, bar_html)

  -- Add label if provided
  if label then
    local label_html = string.format('<div class="%s">%s</div>',
      M.bem_class('progress', 'label'),
      M.escape_html(label))
    return string.format('<div class="%s">%s%s</div>',
      M.bem_class('progress', 'container'),
      label_html,
      wrapper_html)
  end

  return wrapper_html
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return M
