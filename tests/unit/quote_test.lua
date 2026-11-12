local quote = require('quote')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local function attribution_of(text)
  local inlines = pandoc.read(text, 'markdown+smart').blocks[1].content
  local result = quote.attribution(inlines)
  return result and pandoc.utils.stringify(result)
end

cases['quote-attribution-double-hyphen'] = function()
  assert_equal(attribution_of('-- Name, 2026'), 'Name, 2026', 'smart double hyphen')
  assert_equal(attribution_of('-- Name, 2026'), attribution_of('--- Name, 2026'), 'smart triple hyphen')
end

cases['quote-attribution-dashes'] = function()
  assert_equal(attribution_of('\u{2014} Name, 2026'), 'Name, 2026', 'em dash')
  assert_equal(attribution_of('\u{2013} Name, 2026'), 'Name, 2026', 'en dash')
  assert_equal(attribution_of('\u{2014}Name, 2026'), 'Name, 2026', 'em dash without a space')
end

cases['quote-attribution-keeps-markup'] = function()
  local inlines = pandoc.read('-- *Name*, 2026', 'markdown+smart').blocks[1].content
  local result = quote.attribution(inlines)
  assert_equal(result[1].t, 'Emph', 'emphasis kept')
end

cases['quote-attribution-plain-paragraph'] = function()
  assert_equal(attribution_of('A sentence with a dash - inside.'), nil, 'no leading dash')
end

cases['quote-attribution-empty'] = function()
  local ok, err = pcall(attribution_of, '--')
  assert_equal(ok, false, 'a lone dash fails')
  assert_equal(tostring(err):find('holds only a dash', 1, true) ~= nil, true, 'message says what is wrong')
end

return cases
