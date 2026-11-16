--- MC Embedded - Load a filter that an extension bundles, unless the project has its own copy
--- @module "embedded"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil

local M = {}

-- ============================================================================
-- EMBEDDED FILTERS
-- ============================================================================

-- A format extension can bundle other extensions under its own `_extensions/`
-- and name them in its format filters. Quarto adds the filters of a page to
-- the format filters, so a project that keeps its own copy of a bundled
-- extension, and names it, runs both copies. A format names a small wrapper in
-- place of each bundled extension, and the wrapper calls `load`, so only the
-- project copy runs.
--
-- `quarto.utils.resolve_path` answers relative to the script on top of an
-- internal Quarto stack, at load time and when a handler runs. The bundled
-- entry is loaded from the wrapper, so `load` puts the entry on that stack
-- with `_quarto.withScriptFile`, which is internal to Quarto, for the load and
-- for every handler call.
--
-- Quarto gives a filter no list of the filters that a page names, so the
-- module skips the bundled filter when the project has a copy at all. A
-- project that has a copy of a bundled extension but does not name it in
-- `filters` gets neither copy.
-- Remove when: never.

local MANIFESTS = { '_extension.yml', '_extension.yaml' }

--- Tell whether a directory holds an extension manifest.
--- @param dir string
--- @return boolean
local function has_manifest(dir)
  for _, manifest in ipairs(MANIFESTS) do
    local handle = io.open(pandoc.path.join({ dir, manifest }), 'r')
    if handle ~= nil then
      handle:close()
      return true
    end
  end
  return false
end

--- Find a copy of an extension in one `_extensions/` folder.
--- Looks for `<name>/` and `<owner>/<name>/`, with any owner.
--- @param extensions string The `_extensions/` folder
--- @param name string The extension name, such as `veil`
--- @return string|nil The directory of the copy, or nil when there is none
local function find_copy_in(extensions, name)
  local candidates = { pandoc.path.join({ extensions, name }) }
  local listed, owners = pcall(pandoc.system.list_directory, extensions)
  if listed then
    table.sort(owners)
    for _, owner in ipairs(owners) do
      candidates[#candidates + 1] = pandoc.path.join({ extensions, owner, name })
    end
  end
  for _, dir in ipairs(candidates) do
    if has_manifest(dir) then
      return dir
    end
  end
  return nil
end

--- The folders whose `_extensions/` Quarto reads for the input file.
--- From the folder of the input file up to the project directory, as Quarto
--- resolves extensions. Outside a project, only the folder of the input file.
--- @return table<integer, string>
local function search_roots()
  local root = quarto.project and quarto.project.directory
  local input = quarto.doc and quarto.doc.input_file
  if input == nil then
    return { root }
  end
  local dir = pandoc.path.normalize(pandoc.path.directory(input))
  if root == nil then
    return { dir }
  end
  root = pandoc.path.normalize(root)
  local roots = {}
  while dir ~= root and dir:sub(1, #root) == root do
    roots[#roots + 1] = dir
    dir = pandoc.path.directory(dir)
  end
  roots[#roots + 1] = root
  return roots
end

--- Find the project's own copy of an extension.
--- A copy bundled inside another extension is deeper than the folders this
--- looks in, so it never matches.
--- @param name string The extension name, such as `veil`
--- @return string|nil The directory of the copy, or nil when there is none
local function find_project_copy(name)
  for _, root in ipairs(search_roots()) do
    local copy = find_copy_in(pandoc.path.join({ root, '_extensions' }), name)
    if copy ~= nil then
      return copy
    end
  end
  return nil
end

--- Call a function with a file on top of Quarto's script stack.
--- `withScriptFile` keeps only the first value of its callback, so the values
--- are packed and unpacked to keep a second value such as `false`.
--- @param file string
--- @param fn function
--- @param element any The element that Pandoc gives to a handler
--- @return any ...
local function with_script(file, fn, element)
  local results = _quarto.withScriptFile(file, function()
    return table.pack(fn(element))
  end)
  return table.unpack(results, 1, results.n)
end

--- Wrap each handler of a filter so it runs with the entry on the stack.
--- @param file string
--- @param filter table
--- @return table
local function wrap_filter(file, filter)
  local wrapped = {}
  for key, value in pairs(filter) do
    if type(value) == 'function' then
      wrapped[key] = function(element)
        return with_script(file, value, element)
      end
    else
      wrapped[key] = value
    end
  end
  return wrapped
end

--- Load a bundled filter, or skip it when the project has its own copy.
--- The entry runs in its own environment, with `PANDOC_SCRIPT_FILE` set to
--- its path, as Quarto runs a filter. An entry that returns nothing gives the
--- functions it defines as its filter.
--- @param name string The extension name to look for in the project, such as `veil`
--- @param file string The absolute path of the bundled entry, in a folder named `name`
--- @return table The list of filters, empty when skipped
--- @usage return M.load('veil', quarto.utils.resolve_path('../_extensions/mcanouil/veil/veil.lua'))
function M.load(name, file)
  local folder = pandoc.path.filename(pandoc.path.directory(file))
  if folder ~= name then
    error('[embedded] The entry ' .. file .. ' is not in a folder named ' .. name ..
      '. Give the name of the bundled extension that holds the entry.')
  end
  local copy = find_project_copy(name)
  if copy ~= nil then
    quarto.log.debug('[embedded] ' .. name .. ' is skipped: the project has its own copy in ' .. copy .. '.')
    return {}
  end
  if type(_quarto) ~= 'table' or type(_quarto.withScriptFile) ~= 'function' then
    error('[embedded] Could not load ' .. name .. ' from ' .. file ..
      ': this Quarto has no internal `_quarto.withScriptFile`, which the module needs.' ..
      ' Use a Quarto version that has it, or name the bundled filter directly.')
  end
  local env = setmetatable({ PANDOC_SCRIPT_FILE = file }, { __index = _G })
  local result = with_script(file, function()
    local chunk, err = loadfile(file, 'bt', env)
    if chunk == nil then
      error('[embedded] Could not load ' .. name .. ' from ' .. file .. ': ' .. tostring(err))
    end
    return chunk()
  end)
  if result == nil then
    result = { traverse = env.traverse }
    for key, value in pairs(env) do
      if type(value) == 'function' then
        result[key] = value
      end
    end
  end
  if type(result) ~= 'table' then
    error('[embedded] ' .. name .. ' at ' .. file .. ' returned a ' .. type(result) ..
      '. A filter entry must return a filter, a list of filters, or nothing.')
  end
  if result[1] == nil then
    result = { result }
  end
  local filters = {}
  for index, filter in ipairs(result) do
    if type(filter) ~= 'table' then
      error('[embedded] ' .. name .. ' at ' .. file .. ' returned a ' .. type(filter) ..
        ' as filter ' .. index .. '. Each filter in the list must be a table.')
    end
    filters[index] = wrap_filter(file, filter)
  end
  return filters
end

return M
