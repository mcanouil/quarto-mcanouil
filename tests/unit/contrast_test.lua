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

cases['contrast-pair-of-one-preset'] = function()
  local pairs_to_check = { { name = 'fg on bg', fg_token = 'fg', bg_token = 'bg', threshold = 4.5, only = 'mono' } }
  local function get_colour(_, token) return token == 'fg' and '#cccccc' or '#ffffff' end
  assert_equal(#contrast.check(pairs_to_check, get_colour, { 'light' }, 'mono'), 1, 'checked for its preset')
  assert_equal(#contrast.check(pairs_to_check, get_colour, { 'light' }, 'gold'), 0, 'skipped for another preset')
end

cases['contrast-pair-of-one-scheme'] = function()
  local pairs_to_check = { { name = 'fg on bg', fg_token = 'fg', bg_token = 'bg', threshold = 4.5, mode = 'dark' } }
  local colours = { light = { fg = '#cccccc', bg = '#ffffff' }, dark = { fg = '#cccccc', bg = '#ffffff' } }
  local function get_colour(mode, token) return colours[mode][token] end
  local failures = contrast.check(pairs_to_check, get_colour, { 'light', 'dark' })
  assert_equal(#failures, 1, 'checked in its scheme only')
  assert_equal(failures[1].mode, 'dark', 'failing scheme')
end

cases['contrast-pairs-cover-the-deck'] = function()
  local seen = {}
  for _, pair in ipairs(contrast.PAIRS) do
    seen[string.format('%s on %s %g %s', pair.fg_token, pair.bg_token, pair.threshold, pair.mode or 'all')] = true
  end
  for _, name in ipairs({
    'paper on accent-text 4.5 all', 'ground-1 on on-ground-accent 4.5 all', 'on-ground-text on paper 4.5 dark',
    'ink on ground-2 4.5 all', 'muted on ground-2 4.5 all',
  }) do
    assert_equal(seen[name], true, 'pair ' .. name)
  end
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

cases['contrast-terminal-decoration-large-text'] = function()
  local found = nil
  for _, pair in ipairs(contrast.PAIRS) do
    if pair.fg_token == 'accent-high' and pair.bg_token == 'paper' then
      found = pair
    end
  end
  assert_equal(found ~= nil, true, 'accent-high on paper pair')
  assert_equal(found.threshold, 3, 'large text threshold')
  assert_equal(found.only, 'terminal', 'terminal only')
end

cases['focus-ring-contrast'] = function()
  local preset = require('preset')
  local seen = {}
  for _, pair in ipairs(contrast.PAIRS) do
    seen[string.format('%s on %s %g', pair.fg_token, pair.bg_token, pair.threshold)] = true
  end
  for _, surface in ipairs({ 'paper', 'tint', 'card' }) do
    assert_equal(seen['link on ' .. surface .. ' 3'] or seen['link on ' .. surface .. ' 4.5'], true, 'focus ring pair link on ' .. surface)
  end
  assert_equal(seen['muted on card 4.5'], true, 'contents text pair muted on card')
  for _, name in ipairs(preset.PRESETS) do
    local data = preset.read(name)
    for _, mode in ipairs({ 'light', 'dark' }) do
      for _, surface in ipairs({ 'paper', 'tint', 'card' }) do
        local ratio = math_lib.ratio(data[mode].link, data[mode][surface])
        if ratio < 3 then
          error(string.format('%s %s: focus ring link on %s is %.2f, below 3:1', name, mode, surface, ratio))
        end
      end
    end
  end
end

--- Mix two hex colours as CSS `color-mix(in srgb, a p%, b)` does.
local function mix(a, b, share)
  local out = {}
  for i = 0, 2 do
    local x = tonumber(a:sub(2 + 2 * i, 3 + 2 * i), 16)
    local y = tonumber(b:sub(2 + 2 * i, 3 + 2 * i), 16)
    out[#out + 1] = string.format('%02x', math.floor(x * share + y * (1 - share) + 0.5))
  end
  return '#' .. table.concat(out)
end

cases['focus-ring-contrast-mixed-surfaces'] = function()
  local preset = require('preset')
  for _, name in ipairs(preset.PRESETS) do
    local data = preset.read(name)
    for _, mode in ipairs({ 'light', 'dark' }) do
      local t = data[mode]
      local surfaces = {}
      for _, semantic in ipairs({ 'note', 'tip', 'warning', 'important', 'caution' }) do
        surfaces[semantic .. ' callout tint'] = mix(t[semantic], t.paper, 0.07)
      end
      if name == 'gold' then
        surfaces['current contents entry'] = mix(t.accent, t.card, 0.16)
        surfaces['current sidebar page'] = mix(t.accent, t.paper, 0.16)
      end
      for surface, colour in pairs(surfaces) do
        local ratio = math_lib.ratio(t.link, colour)
        if ratio < 3 then
          error(string.format('%s %s: focus ring link on the %s (%s) is %.2f, below 3:1', name, mode, surface, colour, ratio))
        end
      end
    end
  end
end

return cases
