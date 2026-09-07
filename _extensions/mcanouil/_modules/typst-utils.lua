--- @module "typst-utils"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Typst-specific utility functions
--- @description Shared utility functions for Typst-specific shortcodes and filters.
--- Provides value conversion, escaping, and function call generation for Typst output.

local M = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Escape special characters in attribute values for Typst.
--- Escapes backslashes and double quotes to prevent Typst syntax errors.
---
--- @param value string The value to escape
--- @return string Escaped value safe for use in Typst strings
--- @usage local escaped = M.escape_attribute_value('Hello "World"')
M.escape_attribute_value = function(value)
  local result = value:gsub('\\', '\\\\'):gsub('"', '\\"')
  return result
end

--- Convert value to Typst syntax.
--- Converts Lua values to appropriate Typst syntax representations.
--- Handles booleans, numbers, length units, Typst function calls, and strings.
---
--- @param value any The attribute value (will be converted to string)
--- @return string Typst-formatted value (unquoted for booleans/numbers/lengths/functions, quoted for strings)
--- @usage local typst_val = M.typst_value('true')  -- returns 'true' (boolean)
--- @usage local typst_val = M.typst_value('42')    -- returns '42' (number)
--- @usage local typst_val = M.typst_value('75%')   -- returns '75%' (length unit)
--- @usage local typst_val = M.typst_value('10pt')  -- returns '10pt' (length unit)
--- @usage local typst_val = M.typst_value('rgb(...)') -- returns 'rgb(...)' (function call)
--- @usage local typst_val = M.typst_value('text')  -- returns '"text"' (quoted string)
M.typst_value = function(value)
  -- Ensure value is a string
  if value == nil then value = '' end
  if type(value) ~= 'string' then value = tostring(value) end

  -- Boolean conversion
  if value == 'true' then return 'true' end
  if value == 'false' then return 'false' end

  -- Number with unit conversion (e.g., 50%, 1.5em, 10pt, 2cm)
  if value:match('^%-?%d+%.?%d*%%$') or value:match('^%-?%d+%.?%d*[a-z]+$') then
    return value
  end

  -- Number conversion (integer or decimal)
  if value:match('^%-?%d+%.?%d*$') then return value end

  -- Typst function call detection (e.g., rgb(...), color.mix(...))
  -- Pass through without quotes if it looks like a Typst expression
  if value:match('^[%w%.%-]+%b()$') then
    return value
  end

  -- String (default)
  return '"' .. M.escape_attribute_value(value) .. '"'
end

--- Map every spelling a shortcode accepts to the name the schema declares.
--- A Typst function rejects a named argument it does not declare, so a key that
--- the schema does not accept must not reach it, and an alias must arrive under
--- the declared name. Under html an unknown key is ignored by the renderer and
--- reported by the schema check; this gives Typst the same behaviour.
---
--- @param schema table|nil Parsed schema, as held by the shortcode's checker
--- @param shortcode_name string Shortcode name as the schema declares it
--- @return table|nil Map of accepted spelling to declared name, or nil when the
---   schema declares no attributes for this shortcode
--- @usage local spellings = M.accepted_attributes(checker.schema, 'value-box')
M.accepted_attributes = function(schema, shortcode_name)
  local entry = schema and schema.shortcodes and schema.shortcodes[shortcode_name]
  if type(entry) ~= 'table' or type(entry.attributes) ~= 'table' then
    return nil
  end

  local spellings = {}
  for name, descriptor in pairs(entry.attributes) do
    spellings[name] = name
    if type(descriptor) == 'table' and type(descriptor.aliases) == 'table' then
      for _, alias in ipairs(descriptor.aliases) do
        spellings[alias] = name
      end
    end
  end

  return spellings
end

--- Build Typst function call for shortcodes with optional parameter mapping.
--- Generates a complete Typst function call with attributes from keyword arguments.
--- Supports parameter name mapping for localisation or compatibility purposes.
---
--- When `spellings` is given, a key it does not list is left out of the call and
--- an alias is emitted under the name the schema declares. Without it every key
--- is forwarded, which is what callers that pass no schema still get.
---
--- @param function_name string The Typst function name (e.g., 'mcanouil-progress')
--- @param kwargs table Keyword arguments to pass as function parameters
--- @param param_mapping table|nil Optional parameter name mappings (e.g., {old_name = 'new_name'})
--- @param spellings table|nil Accepted spelling to declared name, from `M.accepted_attributes`
--- @return string Complete Typst function call (e.g., '#mcanouil-progress(value: 75)[]')
--- @usage local code = M.build_shortcode_function_call('mcanouil-progress', {value = 75})
--- @usage local code = M.build_shortcode_function_call('mcanouil-progress', {colour = 'blue'})
M.build_shortcode_function_call = function(function_name, kwargs, param_mapping, spellings)
  -- Build attribute string
  local attr_items = {}
  for key, value in pairs(kwargs) do
    local declared_key = key
    if spellings then
      declared_key = spellings[key]
    end

    if declared_key then
      -- Apply parameter name mapping if provided
      local typst_key = declared_key
      if param_mapping and param_mapping[declared_key] then
        typst_key = param_mapping[declared_key]
      end
      table.insert(attr_items, string.format('%s: %s', typst_key, M.typst_value(value)))
    end
  end

  -- Generate function call
  local typst_code
  if #attr_items > 0 then
    local attr_string = table.concat(attr_items, ', ')
    typst_code = string.format('#%s(%s)[]', function_name, attr_string)
  else
    typst_code = string.format('#%s[]', function_name)
  end

  return typst_code
end

--- Create a shortcode handler for Typst format.
--- Factory function that returns a shortcode handler for a given Typst function.
--- The returned handler checks format, builds the function call, and returns a RawBlock.
---
--- @param function_name string The Typst function name to call (e.g., 'mcanouil-divider')
--- @param param_mapping table|nil Optional parameter name mappings
--- @return function Shortcode handler returning pandoc.RawBlock or pandoc.Null
--- @usage return { ['divider'] = M.create_shortcode_handler('mcanouil-divider') }
M.create_shortcode_handler = function(function_name, param_mapping)
  return function(_args, kwargs, _meta)
    if not quarto.doc.is_format('typst') then
      return pandoc.Null()
    end
    local typst_code = M.build_shortcode_function_call(function_name, kwargs, param_mapping)
    return pandoc.RawBlock('typst', typst_code)
  end
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return M
