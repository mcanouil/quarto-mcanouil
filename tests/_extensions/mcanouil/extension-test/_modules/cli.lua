--- Extension Test - The commands this runner gives Quarto.
---
--- This module and `log.lua` are the only places that know the `quarto`
--- command and its output. A later move to q2 changes these two modules and
--- leaves the test documents as they are.

local util = require('util')

local M = {}

--- Read the JSON that `quarto inspect` prints.
---
--- Quarto resolves `output-file` and the project output directory here, so
--- both are read rather than guessed. `_quarto.tests` is read here too,
--- because `quarto inspect` keeps a key with no value, which the vendored
--- YAML reader drops.
--- @param text string
--- @return table|nil info {formats, output_files, output_dir, lib_dir, tests}
--- @return string|nil error
function M.parse_inspect(text)
  local ok, parsed = pcall(pandoc.json.decode, text, false)
  if not ok or type(parsed) ~= 'table' or type(parsed.formats) ~= 'table' then
    return nil, 'quarto inspect returned no formats'
  end

  local output_files = {}
  for name, entry in pairs(parsed.formats) do
    if type(entry) == 'table' and type(entry.pandoc) == 'table' then
      local file = entry.pandoc['output-file']
      if type(file) == 'string' and file ~= '' then
        output_files[name] = file
      end
    end
  end

  -- A project can name any output directory, and a repository that names one
  -- other than `_output` would otherwise have every render read as writing
  -- nothing.
  local output_dir
  local project = type(parsed.project) == 'table' and parsed.project or nil
  local config = project and type(project.config) == 'table' and project.config or nil
  local settings = config and type(config.project) == 'table' and config.project or nil
  if settings and type(settings['output-dir']) == 'string' and settings['output-dir'] ~= '' then
    output_dir = settings['output-dir']
  end
  -- A book or a website writes its support files to one directory for the
  -- whole project rather than to `<output name>_files`.
  local lib_dir
  if settings and type(settings['lib-dir']) == 'string' and settings['lib-dir'] ~= '' then
    lib_dir = settings['lib-dir']
  end

  local formats = util.sorted_keys(parsed.formats)
  local tests
  local first = formats[1] and parsed.formats[formats[1]]
  local metadata = type(first) == 'table' and type(first.metadata) == 'table' and first.metadata or nil
  -- Without metadata the block cannot be read, and reading it as absent
  -- would run the document with none of its assertions.
  if not metadata then
    return nil, 'quarto inspect returned no metadata for ' .. tostring(formats[1])
  end
  if type(metadata._quarto) == 'table' then
    tests = metadata._quarto.tests
  end

  return { formats = formats, output_files = output_files, output_dir = output_dir, lib_dir = lib_dir, tests = tests }, nil
end

--- Run `quarto inspect` on a document or a project directory.
--- @param target string
--- @param cwd string|nil directory to run it from
--- @return string|nil output, string|nil error
local function run_inspect(target, cwd)
  local command = 'quarto inspect ' .. util.shell_quote(target)
  if cwd then
    command = 'cd ' .. util.shell_quote(cwd) .. ' && ' .. command
  end
  local code, output = util.capture(command)
  if code ~= 0 then
    return nil, 'quarto inspect failed: ' .. util.trim(output)
  end
  return output, nil
end

--- Inspect one document.
--- @param document string absolute path
--- @param cwd string directory to inspect from
--- @return table|nil info, string|nil error
function M.inspect(document, cwd)
  local output, err = run_inspect(document, cwd)
  if not output then
    return nil, err
  end
  return M.parse_inspect(output)
end

--- The decoded `quarto inspect` output of a project directory.
--- @param dir string project directory
--- @param cwd string|nil directory to run it from
--- @return table|nil parsed, string|nil error
local function inspect_project(dir, cwd)
  local output, err = run_inspect(dir, cwd)
  if not output then
    return nil, err
  end
  local ok, parsed = pcall(pandoc.json.decode, output, false)
  if not ok or type(parsed) ~= 'table' then
    return nil, 'quarto inspect returned no project'
  end
  return parsed, nil
end

--- The `_quarto.tests` block of a project, as Quarto resolves it.
---
--- Read from `quarto inspect <dir>`, because the vendored YAML reader drops
--- a key with no value and Quarto merges that key into every document.
--- @param dir string project directory
--- @return any block `config._quarto.tests`, or nil
--- @return string|nil error
function M.project_tests(dir)
  local parsed, err = inspect_project(dir)
  if not parsed then
    return nil, err
  end
  local config = type(parsed.config) == 'table' and parsed.config or {}
  local quarto = type(config._quarto) == 'table' and config._quarto or {}
  return quarto.tests, nil
end

--- The input documents of a project, in the order Quarto renders them.
---
--- A book lists its chapters here, so the first one is the document that
--- carries the front matter of the whole book.
--- The paths are made relative to the project directory Quarto reports,
--- because Quarto can spell that directory differently from the caller, for
--- example through a symbolic link.
--- @param dir string project directory
--- @return string[]|nil inputs paths relative to the project directory
--- @return string|nil error
function M.project_inputs(dir)
  local parsed, err = inspect_project(dir, dir)
  if not parsed then
    return nil, err
  end
  local inputs = type(parsed.files) == 'table' and parsed.files.input or nil
  if type(inputs) ~= 'table' or #inputs == 0 then
    return nil, 'quarto inspect lists no input document for the project'
  end
  local prefix = type(parsed.dir) == 'string' and (parsed.dir .. '/') or nil
  local relative = {}
  for _, input in ipairs(inputs) do
    if prefix and input:sub(1, #prefix) == prefix then
      input = input:sub(#prefix + 1)
    end
    relative[#relative + 1] = input
  end
  return relative, nil
end

--- The command line that renders one document, or one project, to one format.
--- @param cwd string
--- @param document string absolute path of a document or a project directory
--- @param format string
--- @param log_path string
--- @param timeout number seconds
--- @return string
function M.render_command(cwd, document, format, log_path, timeout)
  return string.format(
    'cd %s && %squarto render %s --to %s --log %s --log-level info --log-format json-stream',
    util.shell_quote(cwd), util.timeout_prefix(timeout), util.shell_quote(document),
    util.shell_quote(format), util.shell_quote(log_path))
end

return M
