local sections = require('sections')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local function header(text, classes, attributes)
  return pandoc.Header(1, { pandoc.Str(text) }, pandoc.Attr('', classes or {}, attributes or {}))
end

local function para(text)
  return pandoc.Para({ pandoc.Str(text) })
end

local function texts(blocks)
  local out = {}
  for _, block in ipairs(blocks) do
    out[#out + 1] = block.t == 'RawBlock' and ('raw:' .. block.text:match('mc%-part%.update%("(%a+)"%)')) or pandoc.utils.stringify(block)
  end
  return table.concat(out, '|')
end

cases['sections-intro-description'] = function()
  local blocks = { header('Design', {}, { description = 'How it was set up.' }), para('First.') }
  assert_equal(sections.intro(blocks, 1), 'How it was set up.', 'description wins')
end

cases['sections-intro-paragraph'] = function()
  local blocks = { header('Design'), pandoc.CodeBlock('x'), para('First.'), para('Second.') }
  assert_equal(sections.intro(blocks, 1), 'First.', 'first paragraph')
end

cases['sections-intro-none'] = function()
  local blocks = { header('Design'), pandoc.Header(2, { pandoc.Str('Sub') }), para('Under a section.') }
  assert_equal(sections.intro(blocks, 1), nil, 'no paragraph before the next heading')
end

cases['sections-toc-depth-default'] = function()
  assert_equal(sections.chapter_toc_depth({}), 2, 'default depth')
end

cases['sections-toc-depth-value'] = function()
  local meta = { extensions = { mcanouil = { ['chapter-toc-depth'] = pandoc.MetaString('1') } } }
  assert_equal(sections.chapter_toc_depth(meta), 1, 'user depth')
end

cases['sections-toc-depth-invalid'] = function()
  local meta = { extensions = { mcanouil = { ['chapter-toc-depth'] = pandoc.MetaString('zero') } } }
  local ok, err = pcall(sections.chapter_toc_depth, meta)
  assert_equal(ok, false, 'invalid depth fails')
  assert_equal(tostring(err):find('chapter-toc-depth', 1, true) ~= nil, true, 'message names the option')
end

cases['sections-reorder'] = function()
  local blocks = {
    header('Intro'), para('a'),
    header('Listings', { 'appendix' }), para('b'),
    header('References', { 'references' }),
    header('Methods'), para('c'),
    header('Extra', { 'supplementary' }), para('d'),
  }
  assert_equal(
    texts(sections.reorder(blocks)),
    'Intro|a|Methods|c|raw:references|References|raw:appendix|Listings|b|raw:supplementary|Extra|d',
    'special sections at the end, in the order references, appendix, supplementary'
  )
end

cases['sections-reorder-keeps-plain'] = function()
  local blocks = { header('Intro'), para('a') }
  assert_equal(texts(sections.reorder(blocks)), 'Intro|a', 'no special section')
end

cases['sections-start-numbering'] = function()
  assert_equal(sections.section_start('appendix'):find('numbering: "A.1"', 1, true) ~= nil, true, 'appendix A.1')
  assert_equal(sections.section_start('supplementary'):find('numbering: "I.1"', 1, true) ~= nil, true, 'supplementary I.1')
  assert_equal(sections.section_start('references'):find('numbering: none', 1, true) ~= nil, true, 'references unnumbered')
end

cases['sections-title-block-description'] = function()
  local block = pandoc.CodeBlock('---\ntitle: Design\ndescription: How it was set up.\n---\n', pandoc.Attr('', { 'quarto-title-block' }))
  assert_equal(sections.title_block_description(block), 'How it was set up.', 'description of the chapter front matter')
  assert_equal(sections.title_block_description(pandoc.CodeBlock('x')), nil, 'other code block')
end

return cases
