local script_dir = arg[0]:match('^(.*)/[^/]*$') or '.'
package.path = script_dir .. '/?.lua;' .. script_dir .. '/../../_extensions/mcanouil/lua/?.lua;' .. package.path

local passed, failed = 0, 0

local function list_tests()
  local pipe = io.popen('ls "' .. script_dir .. '"/*_test.lua 2>/dev/null')
  local files = {}
  if pipe then
    for line in pipe:lines() do
      files[#files + 1] = line
    end
    pipe:close()
  end
  table.sort(files)
  return files
end

for _, file in ipairs(list_tests()) do
  local cases = dofile(file)
  local names = {}
  for name in pairs(cases) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local ok, err = pcall(cases[name])
    if ok then
      passed = passed + 1
      print('pass  ' .. name)
    else
      failed = failed + 1
      print('FAIL  ' .. name)
      print('      ' .. tostring(err))
    end
  end
end

print(string.format('\n%d passed, %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
