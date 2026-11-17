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
    type_options({ type = 'poster' }), 'mcanouil-typst', 'mcanouil: unknown type "poster"; use article, invoice, letter, memo, report.', 'unknown type'
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

cases['resolve-memo-default-kind'] = function()
  local resolved = document.resolve(type_options({ type = 'memo' }), 'mcanouil-typst')
  assert_equal(resolved.type, 'memo', 'memo type')
  assert_equal(resolved.kind, 'note', 'default memo kind')
end

cases['resolve-memo-kind'] = function()
  local resolved = document.resolve(type_options({ type = 'memo', kind = 'minutes' }), 'mcanouil-typst')
  assert_equal(resolved.kind, 'minutes', 'memo kind')
end

cases['resolve-memo-unknown-kind'] = function()
  fails_with(
    type_options({ type = 'memo', kind = 'poster' }),
    'mcanouil-typst',
    'mcanouil: unknown kind "poster" for type "memo"; use agenda, brief, minutes, note.',
    'unknown memo kind'
  )
end

local function memo_meta(fields)
  local memo = {}
  for key, value in pairs(fields) do
    memo[key] = pandoc.MetaInlines({ pandoc.Str(value) })
  end
  return { extensions = { mcanouil = { type = 'memo', memo = memo } } }
end

local function keys(fields)
  local found = {}
  for _, field in ipairs(fields) do
    found[#found + 1] = field.key
  end
  return table.concat(found, ',')
end

cases['memo-fields-note'] = function()
  local fields = document.memo_fields(memo_meta({ to = 'Team', from = 'Ana', date = 'Today' }), 'note')
  assert_equal(keys(fields), 'to,from,date', 'note fields in order')
  assert_equal(pandoc.utils.stringify(fields[2].value), 'Ana', 'from value')
end

cases['memo-fields-missing-left-out'] = function()
  local fields = document.memo_fields(memo_meta({ to = 'Team', date = 'Today' }), 'note')
  assert_equal(keys(fields), 'to,date', 'no empty row for from')
end

cases['memo-fields-ignores-other-kinds'] = function()
  local fields = document.memo_fields(memo_meta({ to = 'Team', place = 'Room 4', present = 'AA' }), 'agenda')
  assert_equal(keys(fields), 'place', 'agenda fields only')
end

cases['memo-fields-date-time-falls-back-to-date'] = function()
  local fields = document.memo_fields(memo_meta({ date = '11 Nov', present = 'AA' }), 'minutes')
  assert_equal(keys(fields), 'date-time,present', 'date-time from date')
  assert_equal(pandoc.utils.stringify(fields[1].value), '11 Nov', 'date-time value')
end

cases['memo-fields-top-level-date'] = function()
  local meta = memo_meta({ to = 'Team' })
  meta.date = pandoc.MetaInlines({ pandoc.Str('2026') })
  assert_equal(keys(document.memo_fields(meta, 'note')), 'to,date', 'document date fills the date field')
end

cases['memo-fields-empty-value-left-out'] = function()
  assert_equal(keys(document.memo_fields(memo_meta({ to = '', from = 'Ana' }), 'note')), 'from', 'empty value')
end

cases['resolve-letter-layout'] = function()
  local resolved = document.resolve(type_options({ type = 'letter' }), 'mcanouil-typst')
  assert_equal(resolved.type, 'letter', 'type')
  assert_equal(resolved.layout, 'standard', 'layout')
end

cases['resolve-invoice-layout'] = function()
  local resolved = document.resolve(type_options({ type = 'invoice' }), 'mcanouil-typst')
  assert_equal(resolved.type, 'invoice', 'type')
  assert_equal(resolved.layout, 'standard', 'layout')
end

local function letter_meta(lang, standard)
  local meta = { extensions = { mcanouil = { type = 'letter', ['letter-standard'] = standard } } }
  meta.lang = lang
  return meta
end

cases['letter-standard-by-language'] = function()
  assert_equal(document.letter_standard(letter_meta('fr')), 'nf', 'fr')
  assert_equal(document.letter_standard(letter_meta('de')), 'din', 'de')
  assert_equal(document.letter_standard(letter_meta('de-AT')), 'din', 'de-AT')
  assert_equal(document.letter_standard(letter_meta('en')), 'nf', 'en')
  assert_equal(document.letter_standard(letter_meta(nil)), 'nf', 'no language')
end

cases['letter-standard-override'] = function()
  assert_equal(document.letter_standard(letter_meta('fr', 'din')), 'din', 'fr with din')
  assert_equal(document.letter_standard(letter_meta('de', 'nf')), 'nf', 'de with nf')
end

cases['letter-standard-unknown'] = function()
  local standard, message = document.letter_standard(letter_meta('fr', 'iso'))
  assert_equal(standard, nil, 'result')
  assert_equal(message, 'mcanouil: unknown letter-standard "iso"; use din, nf.', 'message')
end

return cases
