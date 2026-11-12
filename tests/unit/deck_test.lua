local deck = require('deck')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

cases['deck-motif-ids-unique'] = function()
  local first, second = deck.motif_svg('facets', '1'), deck.motif_svg('facets', '2')
  assert_equal(first:find('id="mc-motif-facets-fill-1"', 1, true) ~= nil, true, 'suffixed id')
  assert_equal(first:find('url(#mc-motif-facets-fill-1)', 1, true) ~= nil, true, 'suffixed reference')
  assert_equal(first:find('url(#mc-motif-facets-fill)', 1, true), nil, 'no bare reference')
  assert_equal(second:find('id="mc-motif-facets-fill-2"', 1, true) ~= nil, true, 'second copy')
  assert_equal(first:find('aria-hidden="true"', 1, true) ~= nil, true, 'hidden')
end

cases['deck-section-number'] = function()
  assert_equal(deck.section_number(2, 'gold'), '2', 'gold')
  assert_equal(deck.section_number(2, 'terminal'), '02', 'terminal')
  assert_equal(deck.section_number(12, 'terminal'), '12', 'terminal two digits')
end

cases['deck-page-on-right'] = function()
  local document = require('document')
  assert_equal(deck.page_on_right(document.furniture({}, 'deck')), true, 'default footer')
  local moved = { extensions = { mcanouil = { footer = { centre = 'page', right = 'title' } } } }
  assert_equal(deck.page_on_right(document.furniture(moved, 'deck')), false, 'page in the centre')
  local version = { extensions = { mcanouil = { footer = { right = 'version' } } } }
  assert_equal(deck.page_on_right(document.furniture(version, 'deck')), false, 'version on the right')
end

cases['deck-ground-gradient'] = function()
  assert_equal(deck.ground_gradient({ ['ground-1'] = '#111111', ['ground-2'] = '#222222' }),
    'linear-gradient(135deg, #111111, #222222)', 'gradient')
end

return cases
