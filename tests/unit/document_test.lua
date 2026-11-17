local document = require('document')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local function options(furniture)
  return { extensions = { mcanouil = furniture } }
end

local function slot_text(slot)
  return slot.kind == 'text' and pandoc.utils.stringify(slot.value) or slot.kind
end

cases['furniture-report-default'] = function()
  local furniture = document.furniture({})
  assert_equal(furniture.header.left.value, 'title', 'header left')
  assert_equal(furniture.header.centre.kind, 'empty', 'header centre')
  assert_equal(furniture.header.right.value, 'chapter', 'header right')
  assert_equal(furniture.footer.left.value, 'author', 'footer left')
  assert_equal(furniture.footer.centre.value, 'version', 'footer centre')
  assert_equal(furniture.footer.right.value, 'page', 'footer right')
end

cases['furniture-user-slot'] = function()
  local furniture = document.furniture(options({ footer = { left = pandoc.MetaInlines({ pandoc.Str('Confidential') }) } }))
  assert_equal(slot_text(furniture.footer.left), 'Confidential', 'literal text')
  assert_equal(furniture.footer.right.value, 'page', 'other slots keep the default')
end

cases['furniture-user-field'] = function()
  local furniture = document.furniture(options({ header = { left = pandoc.MetaInlines({ pandoc.Str('date') }) } }))
  assert_equal(furniture.header.left.kind, 'field', 'keyword is a field')
  assert_equal(furniture.header.left.value, 'date', 'field name')
end

cases['furniture-empty-slot'] = function()
  local furniture = document.furniture(options({ footer = { centre = pandoc.MetaInlines({}) } }))
  assert_equal(furniture.footer.centre.kind, 'empty', 'empty string empties the slot')
end

cases['furniture-center-alias'] = function()
  local furniture = document.furniture(options({ header = { center = pandoc.MetaInlines({ pandoc.Str('Middle') }) } }))
  assert_equal(slot_text(furniture.header.centre), 'Middle', 'center is centre')
end

cases['furniture-centre-and-center'] = function()
  local ok, err = pcall(document.furniture, options({
    header = { centre = pandoc.MetaInlines({ pandoc.Str('A') }), center = pandoc.MetaInlines({ pandoc.Str('B') }) },
  }))
  assert_equal(ok, false, 'both spellings fail')
  assert_equal(tostring(err):find('header.centre', 1, true) ~= nil, true, 'message names the slot')
end

cases['furniture-unknown-slot'] = function()
  local ok, err = pcall(document.furniture, options({ footer = { middle = pandoc.MetaInlines({ pandoc.Str('A') }) } }))
  assert_equal(ok, false, 'unknown slot fails')
  assert_equal(tostring(err):find('footer.middle', 1, true) ~= nil, true, 'message names the key')
end

cases['furniture-resolve-missing-author'] = function()
  local furniture = document.furniture({})
  local inlines = document.resolve(furniture.footer.left, { title = pandoc.MetaInlines({ pandoc.Str('T') }) })
  assert_equal(#inlines, 0, 'no author gives an empty slot')
end

cases['furniture-resolve-authors'] = function()
  local meta = {
    author = pandoc.MetaList({
      pandoc.MetaMap({ name = pandoc.MetaInlines({ pandoc.Str('Ana') }) }),
      pandoc.MetaInlines({ pandoc.Str('Ben') }),
    }),
  }
  local inlines = document.resolve({ kind = 'field', value = 'author' }, meta)
  assert_equal(pandoc.utils.stringify(inlines), 'Ana, Ben', 'author names')
end

cases['furniture-resolve-page'] = function()
  local inlines = document.resolve({ kind = 'field', value = 'page' }, {})
  assert_equal(inlines[1].format, 'typst', 'raw Typst')
  assert_equal(inlines[1].text, '#page-number()', 'page number call')
end

return cases
