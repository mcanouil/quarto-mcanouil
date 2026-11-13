--- @module "chapter-header"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Chapter header of a full HTML report
--- @description In the full layout, an HTML report shows a chapter header in
--- place of the divider and contents pages of Typst: the chapter number, its
--- title, and the list of its sections (label `mcanouil-in-this-chapter`), to the depth of
--- `chapter-toc-depth`. In a single document, the list follows each numbered
--- level 1 heading. In a book, each chapter is a page whose title Quarto
--- moves to the title block, so the list and the chapter kicker go to the
--- title block partial as `mcanouil-chapter-contents` and `mcanouil-kicker`.
--- Runs after Quarto's filters, when the headings carry their numbers.

local fail = require('lib.fail')
local labels = require('lib.labels')
local sections = require('sections')
local document = require('document')

local M = {}

--- @type string Class of the span that holds the number of a heading.
local NUMBER_CLASS = 'header-section-number'

--- @type table<string, string> Label key of the kicker of each kind of book page.
M.KICKERS = { chapter = 'mcanouil-chapter', appendix = 'mcanouil-appendix' }

--- Answer the number of a heading, from the span that Quarto adds.
--- @param block pandoc.Block
--- @return string|nil Number, for example `1.2` or `A.1`
local function number_of(block)
  if block.t ~= 'Header' then
    return nil
  end
  local found = nil
  for _, inline in ipairs(block.content) do
    if inline.t == 'Span' and inline.classes:includes(NUMBER_CLASS) then
      found = pandoc.utils.stringify(inline)
      break
    end
  end
  return found
end

--- Answer the sections of a chapter: the headings after a block, down to a
--- depth under the chapter, until the next heading of the chapter level.
--- @param blocks pandoc.Blocks Document blocks
--- @param from integer Index of the first block after the chapter heading
--- @param chapter_level integer Heading level of the chapter
--- @param depth integer Heading levels under the chapter to list
--- @return table[] Entries of `level` (1 for the first level under the chapter), `id` and `content`
function M.entries(blocks, from, chapter_level, depth)
  local entries = {}
  for index = from, #blocks do
    local block = blocks[index]
    if block.t == 'Header' then
      if block.level <= chapter_level then
        break
      end
      local level = block.level - chapter_level
      if level <= depth and block.identifier ~= '' then
        entries[#entries + 1] = { level = level, id = block.identifier, content = block.content }
      end
    end
  end
  return entries
end

--- Answer the HTML of some inlines.
--- @param inlines pandoc.Inlines
--- @return string HTML
local function inline_html(inlines)
  return (pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), 'html'):gsub('%s+$', ''))
end

--- Escape text for an HTML attribute value.
--- @param text string
--- @return string
local function attribute(text)
  return (text:gsub('&', '&amp;'):gsub('"', '&quot;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

--- Answer the list of the sections of a chapter, or nil when it has none.
--- In a book page the list is named by its title alone; after a chapter
--- heading of a single document, by its title and the chapter number and
--- title, so that each list has its own name.
--- @param entries table[] Entries from `M.entries`
--- @param label string Title of the list
--- @param id string Identifier of the title
--- @param chapter_name string|nil Number and title of the chapter, as text
--- @return string|nil HTML
function M.html(entries, label, id, chapter_name)
  if #entries == 0 then
    return nil
  end
  local items = {}
  for _, entry in ipairs(entries) do
    items[#items + 1] = string.format('<li class="mc-chapter-contents-level-%d"><a href="#%s">%s</a></li>',
      entry.level, entry.id, inline_html(entry.content))
  end
  local name = chapter_name and string.format('aria-label="%s"', attribute(label .. ', ' .. chapter_name))
    or string.format('aria-labelledby="%s"', id)
  return table.concat({
    string.format('<nav class="mc-chapter-contents" %s>', name),
    string.format('<p class="mc-chapter-contents-title" id="%s">%s</p>', id, label),
    '<ol>', table.concat(items), '</ol>',
    '</nav>',
  })
end

--- Insert the list of its sections after each numbered level 1 heading of
--- a single document, when the chapter has sections to list.
--- @param blocks pandoc.Blocks Document blocks
--- @param label string Title of the lists
--- @param depth integer Heading levels under the chapter to list
--- @return pandoc.Blocks Blocks
function M.insert(blocks, label, depth)
  local result = pandoc.Blocks({})
  for index, block in ipairs(blocks) do
    result:insert(block)
    if sections.opens_chapter(block) and number_of(block) ~= nil then
      local html = M.html(M.entries(blocks, index + 1, 1, depth), label,
        'mc-chapter-contents-' .. block.identifier, pandoc.utils.stringify(block.content))
      if html ~= nil then
        result:insert(pandoc.RawBlock('html', html))
      end
    end
  end
  return result
end

--- Answer the kind of a book page: `chapter` when its sections are numbered,
--- `appendix` when they are lettered, nil for a page with numbered level 1
--- headings of its own (a single document) or with no numbered section.
--- @param blocks pandoc.Blocks Document blocks
--- @return string|nil Kind
function M.page_kind(blocks)
  for _, block in ipairs(blocks) do
    if block.t == 'Header' and block.level == 1 and number_of(block) ~= nil then
      return nil
    end
  end
  for _, block in ipairs(blocks) do
    local number = number_of(block)
    if number ~= nil then
      return number:match('^%a') and 'appendix' or 'chapter'
    end
  end
  return nil
end

--- Add the chapter header of a full HTML report.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function chapter_headers(doc)
  if not quarto.doc.is_format('html') or quarto.doc.is_format('revealjs') then
    return doc
  end
  local meta = doc.meta
  local resolved = document.resolve(meta, 'mcanouil-html')
  if resolved == nil or resolved.type ~= 'report' or resolved.layout ~= 'full' then
    return doc
  end
  local depth = sections.chapter_toc_depth(meta)
  local label = labels.get('mcanouil-in-this-chapter')
  if meta.book == nil then
    doc.blocks = M.insert(doc.blocks, label, depth)
    return doc
  end
  local kind = M.page_kind(doc.blocks)
  if kind == nil then
    return doc
  end
  local html = M.html(M.entries(doc.blocks, 1, 1, depth), label, 'mc-chapter-contents')
  if html ~= nil then
    meta['mcanouil-chapter-contents'] = pandoc.MetaBlocks({ pandoc.RawBlock('html', html) })
  end
  meta['mcanouil-kicker'] = pandoc.MetaInlines({ pandoc.Str(labels.get(M.KICKERS[kind])) })
  doc.meta = meta
  return doc
end

--- @type table Filter step of the closing filter, after Quarto's own filters.
M.filter = { Pandoc = fail.guard(chapter_headers) }

return M
