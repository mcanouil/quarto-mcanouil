local motif = require('lib.motif')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

cases['motif-svg-ids-unique'] = function()
  local first, second = motif.svg('facets', '1'), motif.svg('facets', '2')
  assert_equal(first:find('id="mc-motif-facets-fill-1"', 1, true) ~= nil, true, 'suffixed id')
  assert_equal(first:find('url(#mc-motif-facets-fill-1)', 1, true) ~= nil, true, 'suffixed reference')
  assert_equal(first:find('url(#mc-motif-facets-fill)', 1, true), nil, 'no bare reference')
  assert_equal(second:find('id="mc-motif-facets-fill-2"', 1, true) ~= nil, true, 'second copy')
  assert_equal(first:find('aria-hidden="true"', 1, true) ~= nil, true, 'hidden')
end

cases['motif-svg-without-suffix'] = function()
  for _, name in ipairs({ 'facets', 'steps', 'ribbon', 'dots' }) do
    local svg = motif.svg(name)
    assert_equal(svg:find('^<svg') ~= nil, true, name .. ' is SVG')
    assert_equal(svg:find('%s$'), nil, name .. ' has no trailing space')
  end
  assert_equal(motif.svg('facets'):find('id="mc-motif-facets-fill"', 1, true) ~= nil, true, 'id kept as written')
end

cases['motif-svg-unknown'] = function()
  local ok, err = pcall(motif.svg, 'nonesuch')
  assert_equal(ok, false, 'unknown motif fails')
  assert_equal(tostring(err):find('cannot open the motif file', 1, true) ~= nil, true, 'message: ' .. tostring(err))
end

return cases
