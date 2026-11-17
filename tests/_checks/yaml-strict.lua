--- @module "yaml-strict"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Strict YAML load of the manifest files of the extension
--- @description Reads each file given on the command line with the YAML reader of
--- Pandoc, which stops on a syntax error such as an unescaped quote inside a
--- double-quoted scalar. Prints one line per file, `ok <file>` or
--- `fail <file>: <reason>`, and exits non-zero when a file does not load or has
--- no top-level key named after the colon of its argument (`file:key`).

local failed = 0

for _, spec in ipairs(arg) do
  local path, key = spec:match('^(.-):([%w%-]+)$')
  path = path or spec
  local file = io.open(path, 'r')
  if not file then
    failed = failed + 1
    print('fail ' .. path .. ': cannot open the file')
  else
    local text = file:read('a')
    file:close()
    local loaded, result = pcall(pandoc.read, '---\n' .. text .. '\n---\n', 'markdown')
    if not loaded then
      failed = failed + 1
      print('fail ' .. path .. ': ' .. tostring(result):gsub('\n', ' '))
    elseif key and result.meta[key] == nil then
      failed = failed + 1
      print('fail ' .. path .. ': no top-level key "' .. key .. '" after the YAML load')
    else
      print('ok ' .. path)
    end
  end
end

io.stdout:flush()
os.exit(failed == 0 and 0 or 1)
