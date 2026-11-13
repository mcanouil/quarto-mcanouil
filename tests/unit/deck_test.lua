local deck = require('deck')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
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
