local preset = require('preset')

local MODES = { 'light', 'dark' }

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

--- WCAG contrast ratio of two hex colours.
local function contrast(a, b)
  local function luminance(hex)
    local channels = {}
    for i = 0, 2 do
      local c = tonumber(hex:sub(2 + 2 * i, 3 + 2 * i), 16) / 255
      channels[#channels + 1] = c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * channels[1] + 0.7152 * channels[2] + 0.0722 * channels[3]
  end
  local la, lb = luminance(a), luminance(b)
  if la < lb then la, lb = lb, la end
  return (la + 0.05) / (lb + 0.05)
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
  for _, token in ipairs({ 'link', 'on-ground-title', 'chrome' }) do
    local listed = false
    for _, known in ipairs(preset.TOKENS) do
      listed = listed or known == token
    end
    assert_equal(listed, true, 'token ' .. token .. ' listed')
  end
  for _, name in ipairs({ 'gold', 'mono', 'quarto' }) do
    local data = preset.read(name)
    for _, mode in ipairs(MODES) do
      assert_equal(data[mode].link, data[mode]['accent-text'], name .. '.' .. mode .. '.link')
    end
  end
  for _, name in ipairs({ 'gold', 'mono', 'terminal' }) do
    local data = preset.read(name)
    for _, mode in ipairs(MODES) do
      assert_equal(data[mode].chrome, data[mode]['ground-1'], name .. '.' .. mode .. '.chrome')
    end
  end
  for _, name in ipairs(preset.PRESETS) do
    local data = preset.read(name)
    for _, mode in ipairs(MODES) do
      if contrast('#ffffff', data[mode].chrome) < 4.5 then
        error(string.format('%s.%s white on chrome is below 4.5:1', name, mode))
      end
    end
  end
  assert_equal(preset.read('terminal').dark.link, '#6cb6ff', 'terminal link')
  assert_equal(preset.read('quarto').light.chrome, '#365f84', 'quarto chrome')
  for _, name in ipairs(preset.PRESETS) do
    local data = preset.read(name)
    for _, mode in ipairs(MODES) do
      local title = data[mode]['on-ground-title']
      for _, ground in ipairs({ 'ground-1', 'ground-2' }) do
        if contrast(title, data[mode][ground]) < 4.5 then
          error(string.format('%s.%s on-ground-title on %s is below 4.5:1', name, mode, ground))
        end
      end
    end
  end
  local mono = preset.read('mono').dark
  for _, ground in ipairs({ 'paper', 'tint' }) do
    if contrast(mono['important-text'], mono[ground]) < 4.5 then
      error('mono.dark important-text on ' .. ground .. ' is below 4.5:1')
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
  if not tostring(err):find('extensions.mcanouil.preset', 1, true) then
    error('the error does not name the key path: ' .. tostring(err))
  end
end

cases['preset-key-path'] = function()
  assert_equal(preset.resolve({ extensions = { mcanouil = { preset = 'mono' } } }).name, 'mono', 'extensions key')
  assert_equal(preset.resolve({ mcanouil = { preset = 'mono' } }).name, 'gold', 'old top-level key ignored')
end

cases['font-families'] = function()
  assert_equal(preset.css_family('Source Serif 4', 'serif'), '"Source Serif 4", serif', 'css serif fallback')
  assert_equal(preset.css_family('Fira Code', 'monospace'), '"Fira Code", monospace', 'css monospace fallback')
  assert_equal(preset.css_family('Inter, sans-serif', 'serif'), 'Inter, sans-serif', 'css stack kept')
  local families = preset.typst_families('"Inter", Helvetica Neue, sans-serif')
  assert_equal(#families, 2, 'typst family count, generic family dropped')
  assert_equal(families[1], 'Inter', 'typst first family')
  assert_equal(families[2], 'Helvetica Neue', 'typst second family')
  assert_equal(preset.read('gold').fonts.generic.base, 'serif', 'gold base generic')
  assert_equal(preset.read('mono').fonts.generic.base, 'sans-serif', 'mono base generic')
  assert_equal(preset.read('terminal').fonts.generic.base, 'monospace', 'terminal base generic')
end

return cases
