local chapter_header = require('chapter-header')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local function numbered(level, number, text, id)
  return pandoc.Header(level, { pandoc.Span({ pandoc.Str(number) }, { class = 'header-section-number' }), pandoc.Space(), pandoc.Str(text) }, { id = id })
end

local function sample()
  return pandoc.Blocks({
    pandoc.Header(1, { pandoc.Str('Introduction') }, { id = 'introduction', class = 'unnumbered' }),
    pandoc.Para({ pandoc.Str('Text.') }),
    numbered(1, '1', 'Design', 'design'),
    numbered(2, '1.1', 'Objectives', 'objectives'),
    numbered(3, '1.1.1', 'Secondary', 'secondary'),
    numbered(4, '1.1.1.1', 'Deep', 'deep'),
    numbered(2, '1.2', 'Plan', 'plan'),
    numbered(1, '2', 'Results', 'results'),
    numbered(2, '2.1', 'Outcome', 'outcome'),
  })
end

cases['chapter-header-entries-to-depth'] = function()
  local entries = chapter_header.entries(sample(), 4, 1, 2)
  assert_equal(#entries, 3, 'entries of chapter 1 to depth 2')
  assert_equal(entries[1].id, 'objectives', 'first entry')
  assert_equal(entries[2].level, 2, 'second entry one level down')
  assert_equal(entries[3].id, 'plan', 'last entry before the next chapter')
end

cases['chapter-header-nav-html'] = function()
  local entries = chapter_header.entries(sample(), 4, 1, 2)
  local html = chapter_header.html(entries, 'In this chapter', 'mc-chapter-contents-design', '1 Design & "plan"')
  assert_equal(html:find('<nav class="mc-chapter-contents" aria-label="In this chapter, 1 Design &amp; &quot;plan&quot;">', 1, true) ~= nil, true, 'nav named by its title and the chapter number and title: ' .. html)
  local book = chapter_header.html(entries, 'In this chapter', 'mc-chapter-contents')
  assert_equal(book:find('<nav class="mc-chapter-contents" aria-labelledby="mc-chapter-contents">', 1, true) ~= nil, true, 'book page nav named by its title: ' .. book)
  assert_equal(html:find('<p class="mc-chapter-contents-title" id="mc-chapter-contents-design">In this chapter</p>', 1, true) ~= nil, true, 'title')
  assert_equal(html:find('<li class="mc-chapter-contents-level-1"><a href="#objectives"><span class="header-section-number">1.1</span> Objectives</a></li>', 1, true) ~= nil, true, 'entry with its number: ' .. html)
  assert_equal(html:find('mc-chapter-contents-level-2"><a href="#secondary"', 1, true) ~= nil, true, 'nested entry')
end

cases['chapter-header-insert-after-chapters'] = function()
  local blocks = chapter_header.insert(sample(), 'In this chapter', 2)
  assert_equal(blocks[4].t, 'RawBlock', 'nav after the first numbered chapter')
  assert_equal(blocks[4].text:find('href="#plan"', 1, true) ~= nil, true, 'chapter 1 list')
  assert_equal(blocks[4].text:find('aria-label="In this chapter, 1 Design"', 1, true) ~= nil, true, 'chapter 1 name: ' .. blocks[4].text)
  assert_equal(blocks[2].t, 'Para', 'no nav after an unnumbered heading')
  local count = 0
  for _, block in ipairs(blocks) do
    if block.t == 'RawBlock' then count = count + 1 end
  end
  assert_equal(count, 2, 'one nav for each numbered chapter')
end

cases['chapter-header-empty-list'] = function()
  assert_equal(chapter_header.html({}, 'In this chapter', 'mc-chapter-contents'), nil, 'no list without sections')
end

cases['chapter-header-page-kind'] = function()
  assert_equal(chapter_header.page_kind(sample()), nil, 'a page with level 1 chapters is not a book chapter page')
  local page = pandoc.Blocks({ numbered(2, '1.1', 'Objectives', 'objectives') })
  assert_equal(chapter_header.page_kind(page), 'chapter', 'numbered sections make a chapter page')
  local appendix = pandoc.Blocks({ numbered(2, 'A.1', 'Listings', 'listings') })
  assert_equal(chapter_header.page_kind(appendix), 'appendix', 'lettered sections make an appendix page')
  local plain = pandoc.Blocks({ pandoc.Header(2, { pandoc.Str('Notes') }, { id = 'notes' }) })
  assert_equal(chapter_header.page_kind(plain), nil, 'unnumbered sections make no chapter page')
end

return cases
