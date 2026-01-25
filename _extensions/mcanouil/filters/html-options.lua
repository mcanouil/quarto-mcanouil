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

--- @module html-options
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief HTML options filter
--- @description Processes YAML options for HTML format styling.
--- Supports:
---   - style: 'professional' or 'academic' (converts to style.professional/style.academic booleans)
---   - mc-hide-navbar-title: hides navbar brand/title

-- ============================================================================
-- FORMAT CHECK
-- ============================================================================

-- This filter only applies to HTML format
if not quarto.doc.is_format('html') then
  return {}
end

-- ============================================================================
-- CSS TEMPLATES
-- ============================================================================

local CSS_HIDE_NAVBAR_TITLE = [[
<style>
/* mc-hide-navbar-title: Hide navbar brand/title */
a.navbar-brand {
  display: none;
}
</style>
]]

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get boolean value from metadata
--- @param meta pandoc.Meta Document metadata
--- @param key string Metadata key to read
--- @return boolean True if metadata value is truthy
local function get_bool_option(meta, key)
  if meta[key] == nil then
    return false
  end
  local value = meta[key]
  if type(value) == 'boolean' then
    return value
  end
  if pandoc.utils.type(value) == 'boolean' then
    return value
  end
  -- Handle pandoc MetaInlines/MetaString
  local str = pandoc.utils.stringify(value):lower()
  return str == 'true' or str == 'yes' or str == '1'
end

-- ============================================================================
-- FILTER FUNCTIONS
-- ============================================================================

--- Process metadata and add CSS for enabled options
--- @param meta pandoc.Meta Document metadata
--- @return pandoc.Meta Modified metadata with style booleans
local function Meta(meta)
  -- Convert style string to nested booleans for template use
  -- Default is "professional" if not specified
  local style_value = 'professional' -- default
  if meta['style'] ~= nil then
    style_value = pandoc.utils.stringify(meta['style']):lower()
  end

  -- Create nested style table with boolean values
  meta['style'] = pandoc.MetaMap({
    professional = style_value == 'professional',
    academic = style_value == 'academic'
  })

  -- Check mc-hide-navbar-title option
  if get_bool_option(meta, 'mc-hide-navbar-title') then
    quarto.doc.add_html_dependency({
      name = 'mc-hide-navbar-title',
      version = '1.0.0',
      head = CSS_HIDE_NAVBAR_TITLE
    })
  end

  return meta
end

-- ============================================================================
-- FILTER EXPORT
-- ============================================================================

return {
  { Meta = Meta }
}
