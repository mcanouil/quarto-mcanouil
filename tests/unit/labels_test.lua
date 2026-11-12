local labels = require('lib.labels')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

cases['labels-lookup-language'] = function()
  assert_equal(labels.lookup('mcanouil-exercise', { ['mcanouil-exercise'] = 'Exercice' }), 'Exercice', 'document language')
end

cases['labels-lookup-fallback'] = function()
  assert_equal(labels.lookup('mcanouil-exercise', {}), 'Exercise', 'English fallback')
end

cases['labels-lookup-unknown'] = function()
  local ok, err = pcall(labels.lookup, 'mcanouil-nothing', {})
  assert_equal(ok, false, 'unknown key fails')
  assert_equal(tostring(err):find('mcanouil-nothing', 1, true) ~= nil, true, 'message names the key')
end

cases['labels-files-same-keys'] = function()
  local english, french = labels.read('_language.yml'), labels.read('_language-fr.yml')
  for key in pairs(english) do
    if french[key] == nil then error('missing in _language-fr.yml: ' .. key) end
  end
  for key in pairs(french) do
    if english[key] == nil then error('missing in _language.yml: ' .. key) end
  end
end

cases['labels-files-same-placeholders'] = function()
  local english, french = labels.read('_language.yml'), labels.read('_language-fr.yml')
  for key, value in pairs(english) do
    local function placeholders(text)
      local found = {}
      for name in text:gmatch('{([%w-]+)}') do found[#found + 1] = name end
      table.sort(found)
      return table.concat(found, ',')
    end
    assert_equal(placeholders(french[key]), placeholders(value), 'placeholders of ' .. key)
  end
end

cases['labels-typst-string'] = function()
  assert_equal(labels.typst_string('a "b" \\c'), '"a \\"b\\" \\\\c"', 'escaped literal')
end

return cases
