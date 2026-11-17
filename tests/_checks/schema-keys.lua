--- @module "schema-keys"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Check that the test documents use only the options the schema declares
--- @description Usage: `quarto pandoc lua schema-keys.lua <_schema.yml> < <list>`, with one
--- document path per line of the standard input.
--- Reads `extensions.mcanouil` of each document and checks each key against
--- `options` of the schema, and each key of a map value against the
--- `properties` (with their `aliases`) of that option. Checks each attribute of
--- a div with a class that the schema lists under `classes` or `attributes`
--- against `attributes.<class>`; a `data-` attribute is free. A document that expects the render to fail
--- (`shouldError: true`) is not checked, because it may use a wrong key on
--- purpose. Prints one `unknown <file>: <path>` line per key that the schema
--- lacks, and exits non-zero when there is one.

--- Read a YAML or Markdown file with Pandoc.
--- @param path string File
--- @param yaml boolean Whether the file is plain YAML
--- @return pandoc.Pandoc Document
local function read(path, yaml)
  local file = assert(io.open(path, 'r'), 'cannot open ' .. path)
  local text = file:read('a')
  file:close()
  if yaml then
    text = '---\n' .. text .. '\n---\n'
  end
  return pandoc.read(text, 'markdown')
end

--- Answer whether a metadata value is a map.
--- @param value any
--- @return boolean
local function is_map(value)
  return pandoc.utils.type(value) == 'table' and value[1] == nil and next(value) ~= nil
end

--- Answer the property names of a schema option, with their aliases.
--- @param option table Schema entry
--- @return table<string, boolean>|nil Names, or nil when the option has no properties
local function property_names(option)
  local properties = option and option.properties
  if not is_map(properties) then
    return nil
  end
  local names = {}
  for name, entry in pairs(properties) do
    names[name] = true
    for _, alias in ipairs(entry.aliases or {}) do
      names[pandoc.utils.stringify(alias)] = true
    end
  end
  return names
end

local schema = read(arg[1], true).meta
local options = schema.options or {}
local classes = schema.classes or {}
local attributes = schema.attributes or {}
local unknown = 0

--- Report a key that the schema lacks.
--- @param path string Document
--- @param key string Key path
local function report(path, key)
  unknown = unknown + 1
  print('unknown ' .. path .. ': ' .. key)
end

for path in io.lines() do
  local doc = read(path, false)
  local tests = doc.meta._quarto and doc.meta._quarto.tests
  local should_error = false
  if tests then
    for _, entry in pairs(tests) do
      if is_map(entry) and entry.shouldError == true then
        should_error = true
      end
    end
  end
  if not should_error then
    local mcanouil = doc.meta.extensions and doc.meta.extensions.mcanouil or {}
    for key, value in pairs(mcanouil) do
      local option = options[key]
      if option == nil then
        report(path, 'extensions.mcanouil.' .. key)
      else
        local names = property_names(option)
        if names and is_map(value) then
          for sub in pairs(value) do
            if not names[sub] then
              report(path, 'extensions.mcanouil.' .. key .. '.' .. sub)
            end
          end
        end
      end
    end
    doc.blocks:walk({
      Div = function(div)
        for _, class in ipairs(div.classes) do
          if classes[class] ~= nil or attributes[class] ~= nil then
            local declared = attributes[class] or {}
            for name in pairs(div.attributes) do
              if declared[name] == nil and not name:match('^data%-') then
                report(path, '.' .. class .. ' ' .. name)
              end
            end
          end
        end
      end,
    })
  end
end

io.stdout:flush()
os.exit(unknown == 0 and 0 or 1)
