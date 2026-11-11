local preset = require('preset')

local MODES = { 'light', 'dark' }

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local cases = {}

cases['tokens-complete'] = function()
  assert_equal(#preset.PRESETS, 4, 'preset count')
  for _, name in ipairs(preset.PRESETS) do
    local data = preset.read(name)
    for _, mode in ipairs(MODES) do
      for _, token in ipairs(preset.TOKENS) do
        local value = data[mode] and data[mode][token]
        if not (value and value:match('^#%x%x%x%x%x%x$')) then
          error(string.format('%s.%s.%s is not a 6-digit hex value: %s', name, mode, token, tostring(value)))
        end
      end
    end
    for _, role in ipairs(preset.FONT_ROLES) do
      if not (data.fonts and data.fonts[role] and data.fonts[role] ~= '') then
        error(string.format('%s.fonts.%s is missing', name, role))
      end
    end
  end
  local terminal = preset.read('terminal')
  for _, token in ipairs(preset.TOKENS) do
    assert_equal(terminal.light[token], terminal.dark[token], 'terminal light ' .. token)
  end
end

cases['tokens-user-wins'] = function()
  local data = preset.read('gold')
  local user = {
    light = { primary = '#ff0000', background = '#ffffff', foreground = 'black', ['ground-1'] = '#123' },
    dark = { primary = 'rgb(0, 255, 0)' },
  }
  local tokens = preset.merge(data, function(mode, role) return user[mode][role] end)
  assert_equal(tokens.light.accent, '#ff0000', 'light accent from primary')
  assert_equal(tokens.light.paper, '#ffffff', 'light paper from background')
  assert_equal(tokens.light.ink, '#000000', 'light ink from foreground')
  assert_equal(tokens.light['ground-1'], '#112233', 'light ground-1 from palette')
  assert_equal(tokens.light['accent-text'], data.light['accent-text'], 'light accent-text from preset')
  assert_equal(tokens.dark.accent, '#00ff00', 'dark accent from primary')
  assert_equal(tokens.dark.paper, data.dark.paper, 'dark paper from preset')
end

cases['tokens-bad-user-colour'] = function()
  local ok, err = pcall(preset.merge, preset.read('gold'), function(_, role)
    if role == 'primary' then return 'var(--x)' end
  end)
  assert_equal(ok, false, 'merge with an unreadable colour fails')
  if not tostring(err):find('primary', 1, true) then
    error('the error does not name the role: ' .. tostring(err))
  end
end

cases['preset-unknown-errors'] = function()
  local ok, err = pcall(preset.resolve_name, 'neon')
  assert_equal(ok, false, 'unknown preset fails')
  for _, name in ipairs({ 'gold', 'mono', 'quarto', 'terminal' }) do
    if not tostring(err):find(name, 1, true) then
      error('the error does not name ' .. name .. ': ' .. tostring(err))
    end
  end
  assert_equal(preset.resolve_name(nil), 'gold', 'default preset')
end

return cases
