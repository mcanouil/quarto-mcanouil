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
  local inlines = document.resolve_slot(furniture.footer.left, { title = pandoc.MetaInlines({ pandoc.Str('T') }) })
  assert_equal(#inlines, 0, 'no author gives an empty slot')
end

cases['furniture-resolve-authors'] = function()
  local meta = {
    author = pandoc.MetaList({
      pandoc.MetaMap({ name = pandoc.MetaInlines({ pandoc.Str('Ana') }) }),
      pandoc.MetaInlines({ pandoc.Str('Ben') }),
    }),
  }
  local inlines = document.resolve_slot({ kind = 'field', value = 'author' }, meta)
  assert_equal(pandoc.utils.stringify(inlines), 'Ana, Ben', 'author names')
end

cases['furniture-resolve-two-authors'] = function()
  local meta = { author = pandoc.MetaList({ pandoc.MetaInlines({ pandoc.Str('Ana') }), pandoc.MetaInlines({ pandoc.Str('Ben') }) }) }
  local inlines = document.resolve_slot({ kind = 'field', value = 'author' }, meta, 'et al.')
  assert_equal(pandoc.utils.stringify(inlines), 'Ana, Ben', 'two authors are both named')
end

cases['furniture-resolve-et-al'] = function()
  local meta = {
    author = pandoc.MetaList({
      pandoc.MetaInlines({ pandoc.Str('Ana') }),
      pandoc.MetaInlines({ pandoc.Str('Ben') }),
      pandoc.MetaInlines({ pandoc.Str('Cleo') }),
    }),
  }
  local inlines = document.resolve_slot({ kind = 'field', value = 'author' }, meta, 'et al.')
  assert_equal(pandoc.utils.stringify(inlines), 'Ana et al.', 'first author and the et al. label')
end

cases['furniture-resolve-page'] = function()
  local inlines = document.resolve_slot({ kind = 'field', value = 'page' }, {})
  assert_equal(inlines[1].format, 'typst', 'raw Typst')
  assert_equal(inlines[1].text, '#page-number()', 'page number call')
end

local function type_options(values)
  return { extensions = { mcanouil = values } }
end

local function fails_with(meta, format, expected, what)
  local resolved, message = document.resolve(meta, format)
  assert_equal(resolved, nil, what .. ' result')
  assert_equal(message, expected, what .. ' message')
end

cases['resolve-defaults'] = function()
  local resolved = document.resolve({}, 'mcanouil-typst')
  assert_equal(resolved.type, 'report', 'default type')
  assert_equal(resolved.layout, 'compact', 'default layout')
  assert_equal(resolved.kind, nil, 'default kind')
end

cases['resolve-reads-options'] = function()
  local resolved = document.resolve(type_options({ type = 'report', layout = 'compact' }), 'mcanouil-html')
  assert_equal(resolved.type, 'report', 'type')
  assert_equal(resolved.layout, 'compact', 'layout')
end

cases['resolve-full-layout'] = function()
  local resolved = document.resolve(type_options({ type = 'report', layout = 'full' }), 'mcanouil-typst')
  assert_equal(resolved.layout, 'full', 'full layout')
end

cases['resolve-unknown-type'] = function()
  fails_with(
    type_options({ type = 'poster' }), 'mcanouil-typst', 'mcanouil: unknown type "poster"; use article, report.', 'unknown type'
  )
end

cases['resolve-unknown-layout'] = function()
  fails_with(
    type_options({ layout = 'wide' }),
    'mcanouil-typst',
    'mcanouil: unknown layout "wide" for type "report"; use compact, full.',
    'unknown layout'
  )
end

cases['resolve-pdf-only-html'] = function()
  for _, name in ipairs({ 'letter', 'invoice' }) do
    local expected = string.format('mcanouil: type "%s" supports mcanouil-typst only, not mcanouil-html.', name)
    fails_with(type_options({ type = name }), 'mcanouil-html', expected, name)
  end
end

cases['resolve-pdf-only-revealjs'] = function()
  fails_with(
    type_options({ type = 'invoice' }),
    'mcanouil-revealjs',
    'mcanouil: type "invoice" supports mcanouil-typst only, not mcanouil-revealjs.',
    'invoice on revealjs'
  )
end

cases['resolve-revealjs-deck'] = function()
  assert_equal(document.resolve({}, 'mcanouil-revealjs').type, 'deck', 'no type')
  assert_equal(document.resolve(type_options({ type = 'report' }), 'mcanouil-revealjs').type, 'deck', 'report type')
  assert_equal(document.resolve(type_options({ type = 'poster' }), 'mcanouil-revealjs').type, 'deck', 'unknown type')
end

cases['resolve-revealjs-workshop'] = function()
  assert_equal(document.resolve(type_options({ type = 'workshop' }), 'mcanouil-revealjs').type, 'workshop', 'workshop')
end

cases['furniture-deck-default'] = function()
  local furniture = document.furniture({}, 'deck')
  assert_equal(furniture.header.left.kind, 'empty', 'header left')
  assert_equal(furniture.footer.left.value, 'speaker', 'footer left')
  assert_equal(furniture.footer.centre.value, 'title', 'footer centre')
  assert_equal(furniture.footer.right.value, 'page', 'footer right')
end

cases['slot-speaker-event'] = function()
  local meta = {
    author = pandoc.MetaInlines({ pandoc.Str('Ada') }),
    extensions = { mcanouil = { event = pandoc.MetaInlines({ pandoc.Str('useR!'), pandoc.Space(), pandoc.Str('2026') }) } },
  }
  local text = pandoc.utils.stringify(document.resolve_slot({ kind = 'field', value = 'speaker' }, meta))
  assert_equal(text, 'Ada · useR! 2026', 'speaker and event')
  meta.extensions = nil
  assert_equal(pandoc.utils.stringify(document.resolve_slot({ kind = 'field', value = 'speaker' }, meta)), 'Ada', 'speaker only')
end

return cases
