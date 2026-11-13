local html_page = require('html-page')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local function decode(text)
  return (text:gsub('%%(%x%x)', function(hex) return string.char(tonumber(hex, 16)) end))
end

cases['html-page-motif-mask'] = function()
  for _, motif in ipairs({ 'facets', 'steps', 'ribbon', 'dots' }) do
    local mask = html_page.motif_mask(motif)
    local data = mask:match('^url%("data:image/svg%+xml,(.*)"%)$')
    assert_equal(data ~= nil, true, motif .. ' mask is a data URL: ' .. mask:sub(1, 60))
    assert_equal(data:find('[%s"#<>]'), nil, motif .. ' data URL has no raw space, quote, hash or bracket')
    local svg = decode(data)
    assert_equal(svg:find('^<svg') ~= nil, true, motif .. ' decodes to SVG')
    assert_equal(svg:find('var(', 1, true), nil, motif .. ' mask has no custom property, which an image cannot read')
    assert_equal(svg:find('viewBox="0 0 100 100"', 1, true) ~= nil, true, motif .. ' keeps the view box')
  end
end

return cases
