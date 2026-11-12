--- @module "sections"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Chapters and special sections of a Typst report
--- @description Numbers the special sections of a report: references are not
--- numbered, appendices are numbered A.1 and supplementary sections I.1. In a
--- single document they are level 1 headings with the class `references`,
--- `appendix` or `supplementary`, moved to the end in that order. In a book
--- project the appendices are the `book.appendices` chapters, kept in place.
--- Places the bibliography where the `refs` div is. In the full layout, adds
--- after each numbered chapter heading the call that ends its divider page and
--- writes its chapter contents page, with the introduction line of the
--- chapter: its `description`, or else the first sentence of its first
--- paragraph. Book parts, such as the appendices, get a divider of their own.

local fail = require('lib.fail')
local labels = require('lib.labels')

local M = {}

--- @type string[] Special section kinds, in the order they come at the end of a document.
M.SPECIAL = { 'references', 'appendix', 'supplementary' }

--- @type table<string, string> Heading numbering of each special section kind.
M.NUMBERING = { references = 'none', appendix = '"A.1"', supplementary = '"I.1"' }

--- @type integer Default of `extensions.mcanouil.chapter-toc-depth`.
M.DEFAULT_CHAPTER_TOC_DEPTH = 2

--- @type string Class of the code block that holds the front matter of a book chapter.
local TITLE_BLOCK_CLASS = 'quarto-title-block'

--- @type string Class of the block that Quarto wraps around a book part heading.
local PART_CLASS = 'quarto-book-part'

--- @type string Pattern of the marker that Quarto writes before each book item.
local BOOK_MARKER = '^<!%-%- quarto%-file%-metadata: ([^ ]+) %-%->$'

--- Answer the Typst code that starts a special section: the heading counter
--- restarts, the numbering changes, and the `mc-part` state names the kind.
--- @param kind string `references`, `appendix` or `supplementary`
--- @return string Typst code, at the top level of the document
function M.section_start(kind)
  return table.concat({
    '#counter(heading).update(0)',
    string.format('#mc-part.update("%s")', kind),
    string.format('#set heading(numbering: %s)', M.NUMBERING[kind]),
  }, '\n')
end

--- Answer the special section kind of a block.
--- @param block pandoc.Block
--- @return string|nil Kind, when the block is a level 1 heading with a special class
local function special_kind(block)
  if block.t ~= 'Header' or block.level ~= 1 then
    return nil
  end
  for _, kind in ipairs(M.SPECIAL) do
    if block.classes:includes(kind) then
      return kind
    end
  end
  return nil
end

--- Move the special sections of a single document to its end, in the order
--- of `M.SPECIAL`, each kind after the code that starts it. A special
--- section runs from its heading to the next level 1 heading.
--- @param blocks pandoc.Blocks|table Document blocks
--- @return pandoc.Blocks Blocks
function M.reorder(blocks)
  local kept = pandoc.Blocks({})
  local moved = {}
  local current = nil
  for _, block in ipairs(blocks) do
    if block.t == 'Header' and block.level == 1 then
      current = special_kind(block)
    end
    if current then
      moved[current] = moved[current] or pandoc.Blocks({})
      moved[current]:insert(block)
    else
      kept:insert(block)
    end
  end
  for _, kind in ipairs(M.SPECIAL) do
    if moved[kind] then
      kept:insert(pandoc.RawBlock('typst', M.section_start(kind)))
      kept:extend(moved[kind])
    end
  end
  return kept
end

--- Answer the inlines of the first sentence of a list of inlines: up to and
--- including the first string that ends with a full stop, a question mark or
--- an exclamation mark.
--- @param inlines pandoc.Inlines
--- @return pandoc.Inlines First sentence
local function first_sentence(inlines)
  local sentence = pandoc.Inlines({})
  for _, inline in ipairs(inlines) do
    sentence:insert(inline)
    if inline.t == 'Str' and inline.text:match('[.?!]$') then
      break
    end
  end
  return sentence
end

--- Answer the introduction line of the chapter whose heading is `blocks[index]`:
--- its `description` attribute, or else the first sentence of its first
--- paragraph before the next heading. The paragraph stays in the body.
--- @param blocks pandoc.Blocks|table Document blocks
--- @param index integer Index of the chapter heading
--- @return pandoc.Inlines|nil Inlines, or nil when the chapter has neither
function M.intro(blocks, index)
  local description = blocks[index].attributes.description
  if description ~= nil and description ~= '' then
    return pandoc.Inlines(description)
  end
  for position = index + 1, #blocks do
    local block = blocks[position]
    if block.t == 'Header' then
      return nil
    end
    if block.t == 'Para' then
      local sentence = first_sentence(block.content)
      return pandoc.utils.stringify(sentence) ~= '' and sentence or nil
    end
  end
  return nil
end

--- Answer inlines as Typst markup, with no surrounding white space.
--- @param inlines pandoc.Inlines
--- @return string Markup
function M.typst_markup(inlines)
  local markup = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), 'typst')
  return (markup:gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Answer whether a level 1 heading opens a chapter with a divider and a
--- contents page: it is numbered, and it is not the references.
--- @param block pandoc.Block
--- @return boolean
function M.opens_chapter(block)
  return block.t == 'Header' and block.level == 1
    and not block.classes:includes('unnumbered') and not block.classes:includes('references')
end

--- Answer `extensions.mcanouil.chapter-toc-depth`: how many heading levels
--- under the chapter its contents page lists.
--- @param meta table Document metadata
--- @return integer Depth
function M.chapter_toc_depth(meta)
  local options = meta.extensions and meta.extensions.mcanouil or {}
  local value = options['chapter-toc-depth']
  if value == nil then
    return M.DEFAULT_CHAPTER_TOC_DEPTH
  end
  local text = pandoc.utils.stringify(value)
  local depth = tonumber(text)
  if depth == nil or depth < 1 or depth ~= math.floor(depth) then
    fail.raise(string.format(
      'mcanouil: chapter-toc-depth "%s" in extensions.mcanouil is not valid; use a whole number of 1 or more.', text
    ))
  end
  return depth
end

--- Answer the `description` of the front matter of a book chapter, which
--- Quarto passes as a code block of class `quarto-title-block`.
--- @param block pandoc.Block
--- @return string|nil Description
function M.title_block_description(block)
  if block.t ~= 'CodeBlock' or not block.classes:includes(TITLE_BLOCK_CLASS) then
    return nil
  end
  local description = pandoc.read(block.text, 'markdown').meta.description
  return description ~= nil and pandoc.utils.stringify(description) or nil
end

--- Answer the book item that a marker block announces.
--- @param block pandoc.Block
--- @return table|nil Book item, with `bookItemType`, or nil when the block is not a marker
local function book_item(block)
  if block.t ~= 'RawBlock' or block.format ~= 'html' then
    return nil
  end
  local encoded = block.text:match(BOOK_MARKER)
  if encoded == nil then
    return nil
  end
  local item = quarto.json.decode(quarto.base64.decode(encoded))
  return item.bookItemType ~= nil and item or nil
end

--- Answer whether a block holds a book item marker of type appendix: the
--- marker itself, or the part divider that Quarto wraps around it.
--- @param block pandoc.Block
--- @return boolean|nil `true` for an appendix, `false` for another book item, nil for no marker
local function appendix_marker(block)
  local blocks = block.t == 'Div' and block.content or { block }
  for _, inner in ipairs(blocks) do
    local item = book_item(inner)
    if item ~= nil then
      return item.bookItemType == 'appendix'
    end
  end
  return nil
end

--- Start the appendices of a book before the first appendix item, and start
--- any special section that a chapter heading marks with a class.
--- @param blocks pandoc.Blocks Document blocks
--- @return pandoc.Blocks|nil Blocks, or nil when the document is not a book
local function number_book(blocks)
  local result = pandoc.Blocks({})
  local is_book, in_appendix = false, false
  for _, block in ipairs(blocks) do
    local appendix = appendix_marker(block)
    if appendix ~= nil then
      is_book = true
      if appendix and not in_appendix then
        in_appendix = true
        result:insert(pandoc.RawBlock('typst', M.section_start('appendix')))
      end
    end
    local kind = special_kind(block)
    if kind ~= nil then
      result:insert(pandoc.RawBlock('typst', M.section_start(kind)))
    end
    result:insert(block)
  end
  return is_book and result or nil
end

--- Answer the text of a metadata value, with the text of raw inlines kept:
--- Quarto passes paths to Typst as raw Typst inlines.
--- @param value any Metadata value
--- @return string Text
local function raw_text(value)
  if pandoc.utils.type(value) == 'Inlines' then
    value = value:walk({ RawInline = function(raw) return pandoc.Str(raw.text) end })
  end
  return pandoc.utils.stringify(value)
end

--- Format a metadata list of bibliography files as a Typst array of strings.
--- @param value any `bibliography` metadata
--- @return string Typst array
local function bibliography_files(value)
  local files = pandoc.utils.type(value) == 'List' and value or { value }
  local quoted = {}
  for _, file in ipairs(files) do
    quoted[#quoted + 1] = labels.typst_string(raw_text(file))
  end
  return '(' .. table.concat(quoted, ', ') .. ',)'
end

--- Place the bibliography in the `refs` div, with no title of its own, and
--- clear the `bibliography` metadata so the template does not add a second one.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function place_bibliography(doc)
  if doc.meta.bibliography == nil then
    return doc
  end
  local placed = false
  local call = '#bibliography(' .. bibliography_files(doc.meta.bibliography) .. ', title: none'
  if doc.meta.csl ~= nil then
    call = call .. ', style: ' .. labels.typst_string(raw_text(doc.meta.csl))
  end
  call = call .. ')'
  doc.blocks = doc.blocks:walk({
    Div = function(div)
      if div.identifier == 'refs' and not placed then
        placed = true
        return pandoc.RawBlock('typst', call)
      end
    end,
  })
  if placed then
    doc.meta.bibliography = nil
  end
  return doc
end

--- Answer the part divider of a book, from the part block that Quarto wraps
--- around its heading: the heading opens a divider with no number, and the
--- call after it ends the page.
--- @param block pandoc.Div Part block
--- @return pandoc.Div Part block
local function open_part(block)
  local content = pandoc.Blocks({})
  for _, inner in ipairs(block.content) do
    if inner.t == 'Header' and inner.level == 1 then
      content:insert(pandoc.RawBlock('typst', '#mc-part-divider.update(true)'))
      content:insert(inner)
      content:insert(pandoc.RawBlock('typst', '#part-opening()'))
    else
      content:insert(inner)
    end
  end
  block.content = content
  return block
end

--- Add, after each chapter heading that opens a chapter, the call that ends
--- its divider page and writes its chapter contents page, and turn each book
--- part into a divider.
--- @param blocks pandoc.Blocks Document blocks
--- @param depth integer Heading levels under the chapter that its contents page lists
--- @return pandoc.Blocks Blocks
local function open_chapters(blocks, depth)
  local result = pandoc.Blocks({})
  for index, block in ipairs(blocks) do
    if block.t == 'Div' and block.classes:includes(PART_CLASS) then
      block = open_part(block)
    end
    result:insert(block)
    if M.opens_chapter(block) then
      local intro = M.intro(blocks, index)
      local arguments = 'depth: ' .. depth
      if intro ~= nil then
        arguments = arguments .. ', intro: [' .. M.typst_markup(intro) .. ']'
      end
      result:insert(pandoc.RawBlock('typst', '#chapter-opening(' .. arguments .. ')'))
    end
  end
  return result
end

--- Answer the value of a string metadata key.
--- @param meta table Document metadata
--- @param key string Key
--- @return string Value, empty when unset
local function meta_text(meta, key)
  return meta[key] ~= nil and pandoc.utils.stringify(meta[key]) or ''
end

--- Arrange the chapters and special sections of a Typst report.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function arrange(doc)
  if not quarto.doc.is_format('typst') or meta_text(doc.meta, 'mcanouil-type') ~= 'report' then
    return doc
  end
  doc.blocks = number_book(doc.blocks) or M.reorder(doc.blocks)
  doc = place_bibliography(doc)
  if meta_text(doc.meta, 'mcanouil-layout') == 'full' then
    doc.blocks = open_chapters(doc.blocks, M.chapter_toc_depth(doc.meta))
  end
  return doc
end

--- Copy the `description` of the front matter of each book chapter to the
--- attributes of its heading, before Quarto expands the front matter.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function capture_descriptions(doc)
  if not quarto.doc.is_format('typst') then
    return doc
  end
  local chapter = nil
  for _, block in ipairs(doc.blocks) do
    if block.t == 'Header' and block.level == 1 then
      chapter = block
    elseif chapter ~= nil then
      local description = M.title_block_description(block)
      if description ~= nil and chapter.attributes.description == nil then
        chapter.attributes.description = description
      end
      if block.t ~= 'RawBlock' then
        chapter = nil
      end
    end
  end
  return doc
end

--- @type table Filter step of the entry filter, before Quarto's own filters.
M.pre_filter = { Pandoc = fail.guard(capture_descriptions) }

--- @type table Filter step of the closing filter, after Quarto's own filters.
M.filter = { Pandoc = fail.guard(arrange) }

return M
