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

local function html_of(text, label)
  local block = pandoc.read(text, 'markdown+smart').blocks[1]
  local result = quote.html(block, label or 'Quote')
  return result and pandoc.write(pandoc.Pandoc(result), 'html')
end

cases['quote-html-attribution'] = function()
  local html = html_of('> Design for the reader.\n>\n> -- *Name*, 2026')
  local shape = '^<figure class="mc%-quote" data%-mc%-label="Quote">%s*<blockquote>%s*<p>Design for the reader%.</p>%s*'
    .. '</blockquote>%s*<figcaption class="mc%-quote%-attribution" data%-mc%-label="Quote">%s*<em>Name</em>, 2026%s*'
    .. '</figcaption>%s*</figure>%s*$'
  assert_equal(html:find(shape) ~= nil, true, 'figure with the quote and the attribution as its caption: ' .. html)
end

cases['quote-html-plain'] = function()
  local html = html_of('> A plain quote.')
  local shape = '^<figure class="mc%-quote" data%-mc%-label="Quote">%s*<blockquote>%s*<p>A plain quote%.</p>%s*</blockquote>%s*</figure>%s*$'
  assert_equal(html:find(shape) ~= nil, true, 'figure with the quote and no caption: ' .. html)
end

cases['quote-html-label-escaped'] = function()
  local html = html_of('> A quote.', 'Say "hi" & <go>')
  assert_equal(html:find('data-mc-label="Say &quot;hi&quot; &amp; &lt;go&gt;"', 1, true) ~= nil, true, 'escaped label: ' .. html)
end

cases['quote-html-alert-left-alone'] = function()
  assert_equal(html_of('> [!NOTE]\n> A GitHub alert.'), nil, 'an alert stays for Quarto')
end

return cases
