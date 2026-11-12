local math_lib = require('lib.contrast-math')
local contrast = require('contrast')

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local function rounded(value, places)
  return string.format('%.' .. places .. 'f', value)
end

local cases = {}

cases['contrast-ratio-known-values'] = function()
  assert_equal(rounded(math_lib.ratio('#111827', '#fafafa'), 1), '17.0', 'ink on paper')
  assert_equal(rounded(math_lib.ratio('#876208', '#fafafa'), 2), '5.32', 'accent-text on paper')
  assert_equal(rounded(math_lib.ratio('#b5830a', '#fafafa'), 2), '3.24', 'accent on paper')
  assert_equal(rounded(math_lib.ratio('#ffffff', '#3a2a06'), 1), '13.9', 'white on chrome')
end

cases['contrast-ratio-symmetric-and-bounded'] = function()
  assert_equal(math_lib.ratio('#111827', '#fafafa'), math_lib.ratio('#fafafa', '#111827'), 'symmetry')
  assert_equal(math_lib.ratio('#000', '#fff'), 21, 'black on white')
  assert_equal(math_lib.ratio('#abcdef', '#abcdef'), 1, 'same colour')
end

cases['contrast-check-reports-failures'] = function()
  local colours = { light = { fg = '#cccccc', bg = '#ffffff' }, dark = { fg = '#ffffff', bg = '#000000' } }
  local pairs_to_check = { { name = 'fg on bg', fg_token = 'fg', bg_token = 'bg', threshold = 4.5 } }
  local failures = contrast.check(pairs_to_check, function(mode, token) return colours[mode][token] end, { 'light', 'dark' })
  assert_equal(#failures, 1, 'failure count')
  assert_equal(failures[1].mode, 'light', 'failing mode')
  assert_equal(failures[1].message,
    'fg on bg (light) is 1.61:1, below 4.50:1. Change fg or bg in _brand.yml.', 'message')
end

cases['contrast-check-passes-clean-pairs'] = function()
  local pairs_to_check = { { name = 'fg on bg', fg_token = 'fg', bg_token = 'bg', threshold = 3 } }
  local failures = contrast.check(pairs_to_check, function(_, token) return token == 'fg' and '#000000' or '#ffffff' end, { 'light' })
  assert_equal(#failures, 0, 'failure count')
end

cases['contrast-pairs-cover-the-spec'] = function()
  local seen = {}
  for _, pair in ipairs(contrast.PAIRS) do
    seen[string.format('%s on %s %g', pair.fg_token, pair.bg_token, pair.threshold)] = true
  end
  for _, name in ipairs({
    'ink on paper 4.5', 'muted on tint 4.5', 'link on paper 4.5', 'accent-text on tint 4.5',
    'note-text on paper 4.5', 'caution-text on tint 4.5',
    'on-ground-text on ground-2 4.5', 'on-ground-accent on ground-1 4.5', 'on-ground-title on chrome 4.5',
    'accent on paper 3', 'link on paper 3', 'warning on paper 3',
    'accent-high on ground-1 3', 'accent-high on ground-2 3',
  }) do
    assert_equal(seen[name], true, 'pair ' .. name)
  end
end

return cases
