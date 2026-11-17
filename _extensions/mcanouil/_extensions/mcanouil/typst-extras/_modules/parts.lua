--- Typst Extras - Appendix and supplementary parts
--- @module "parts"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Move appendix and supplementary sections to the end of a document, or mark supplementary chapters in a book.
--- @description A section starts at a top-level heading with the `.appendix` or `.supplementary` class,
---   and ends at the next heading of the same level.
---   Appendix sections go to the end of the body, in source order, then supplementary sections.
---   Each part starts with a raw Typst block that sets the part and its heading numbering.
---   In a book, nothing moves: supplementary chapters are marked in place, and the book keeps its appendices.

local options = require(quarto.utils.resolve_path('_modules/options.lua'):gsub('%.lua$', ''))
local emit = require(quarto.utils.resolve_path('_modules/emit.lua'):gsub('%.lua$', ''))
local kinds_module = require(quarto.utils.resolve_path('_modules/kinds.lua'):gsub('%.lua$', ''))

local M = {}

--- Name used in messages.
local MODULE_NAME = 'sections'

--- Parts, in the order they go at the end of the document. Each part is also the class that marks it.
local PARTS = { 'appendix', 'supplementary' }

--- Heading numbering of each part.
local HEADING_NUMBERING = {
  appendix = 'typst-extras-appendix-numbering.with(config: typst-extras-config)',
  supplementary = 'typst-extras-heading-numbering.with(part: "supplementary", config: typst-extras-config)',
}

--- Return the part a heading starts, from its class.
--- @param header pandoc.Header
--- @return string|nil
local function part_of(header)
  for _, part in ipairs(PARTS) do
    if header.classes:includes(part) then
      return part
    end
  end
  return nil
end

--- Return the part a top-level heading starts, and warn when it has both part classes.
--- The `.appendix` class wins, as in `part_of`.
--- @param header pandoc.Header
--- @return string|nil
local function top_part_of(header)
  if header.classes:includes('appendix') and header.classes:includes('supplementary') then
    options.warn(MODULE_NAME, 'the heading "' .. pandoc.utils.stringify(header) .. '" has both the .appendix and ' ..
      '.supplementary classes, so it is an appendix. Remove one of them.')
  end
  return part_of(header)
end

--- Return the top heading level of the document: the smallest level of its top-level headings.
--- Pandoc applies `shift-heading-level-by` after the filters, so the filter cannot see the level Typst gets.
--- The top level stands for Typst level 1: `#` without a shift, `##` with `shift-heading-level-by: -1`.
--- @param blocks pandoc.Blocks
--- @return integer|nil
local function top_level(blocks)
  local level = nil
  for _, block in ipairs(blocks) do
    if block.t == 'Header' and (level == nil or block.level < level) then
      level = block.level
    end
  end
  return level
end

--- Return the raw Typst block that starts a part.
--- @param part string `"appendix"` or `"supplementary"`
--- @param kinds string[] Figure kinds to reset, from `sections.kinds`
--- @return pandoc.Block
function M.part_start(part, kinds)
  return pandoc.RawBlock('typst',
    '#typst-extras-part-start(' .. emit.string(part) .. ', ' .. kinds_module.typst_array(kinds) .. ')')
end

--- Return the raw Typst blocks that start a part in a document: the part start, then the heading numbering of the part.
--- @param part string `"appendix"` or `"supplementary"`
--- @param kinds string[] Figure kinds to reset, from `sections.kinds`
--- @return pandoc.Block[]
function M.start_blocks(part, kinds)
  return {
    M.part_start(part, kinds),
    pandoc.RawBlock('typst', '#set heading(numbering: ' .. HEADING_NUMBERING[part] .. ')'),
  }
end

--- Warn that a part class on a heading below the top level stays in place.
--- @param header pandoc.Header
--- @param advice string What to do instead
local function warn_deep(header, advice)
  options.warn(MODULE_NAME, 'the .' .. part_of(header) .. ' class works on level-1 headings only, so "' ..
    pandoc.utils.stringify(header) .. '" stays in place. ' .. advice)
end

--- Advice for a part class on a deeper heading in a document.
local DEEP_ADVICE = 'Move the class to a level-1 heading.'

--- Advice for a part class on a deeper heading in a book.
local DEEP_BOOK_ADVICE = 'For an appendix, use the book\'s appendices: list. ' ..
  'For a supplementary chapter, put .supplementary on the chapter\'s level-1 heading.'

--- Split the top-level blocks into the body and the sections of each part.
--- A class on a deeper heading warns and stays in place.
--- @param blocks pandoc.Blocks
--- @param top integer The top heading level
--- @return pandoc.Blocks body
--- @return table sections Lists of sections, one list per part; each section is a list of blocks
local function split(blocks, top)
  local body = pandoc.Blocks({})
  local sections = { appendix = {}, supplementary = {} }
  local target = body
  for _, block in ipairs(blocks) do
    if block.t == 'Header' and block.level == top then
      local part = top_part_of(block)
      if part then
        block.classes = block.classes:filter(function(class) return class ~= part end)
        target = pandoc.Blocks({})
        table.insert(sections[part], target)
      else
        target = body
      end
    elseif block.t == 'Header' and part_of(block) then
      warn_deep(block, DEEP_ADVICE)
    end
    target:insert(block)
  end
  return body, sections
end

--- Mark the sub-headings of a section as unnumbered, for documents without `number-sections`.
--- Level-1 headings of a part stay numbered, so they can be referenced.
--- @param section pandoc.Blocks
--- @param top integer The top heading level
local function unnumber_sub_headings(section, top)
  for _, block in ipairs(section) do
    if block.t == 'Header' and block.level > top and not block.classes:includes('unnumbered') then
      block.classes:insert('unnumbered')
    end
  end
end

--- Move the appendix and supplementary sections of a document to its end.
--- Each appendix section after the first starts with a counter reset.
--- The first one needs none, because the part start resets the counters.
--- @param blocks pandoc.Blocks The top-level blocks
--- @param settings table Settings from `sections.settings`
--- @param kinds string[] Figure kinds to reset, from `sections.kinds`
--- @return pandoc.Blocks body The blocks that stay in the body, in source order
--- @return pandoc.Blocks|nil tail The parts to put after the body, or nil when there is none
function M.move(blocks, settings, kinds)
  local top = top_level(blocks)
  if top == nil then
    return blocks, nil
  end
  local body, sections = split(blocks, top)
  local kinds_array = kinds_module.typst_array(kinds)
  local reset = '#typst-extras-reset-chapter(' .. kinds_array .. ')'
  local tail = pandoc.Blocks({})
  for _, part in ipairs(PARTS) do
    if #sections[part] > 0 then
      tail:extend(M.start_blocks(part, kinds))
    end
    for index, section in ipairs(sections[part]) do
      if not settings['number-sections'] then
        unnumber_sub_headings(section, top)
      end
      if part == 'appendix' and index > 1 then
        tail:insert(pandoc.RawBlock('typst', reset))
      end
      tail:extend(section)
    end
  end
  if #tail == 0 then
    return blocks, nil
  end
  return body, tail
end

--- Tell whether a block is the divider that Quarto puts before a part of a book, such as the appendices.
--- @param block pandoc.Block
--- @return boolean
local function book_divider(block)
  return block.t == 'Div' and block.classes:includes('quarto-book-part')
end

--- Mark the supplementary chapters of a book, without moving anything.
--- The book numbers chapters and appendices itself, so an `.appendix` class warns and stays as it is.
--- A run of supplementary chapters starts the supplementary part once, so their headings read `S1`, `S2`.
--- The book resets float and equation counters at each chapter, so each later chapter of the run
--- carries them over its heading, and the run keeps one `S1`, `S2` sequence.
--- A body mark goes before the part start, which sets the heading counter to 0.
--- The heading numbering comes from `typst-extras-book-heading-numbering`, set once by the caller,
--- so the book keeps its own heading numbering outside the supplementary part.
--- The part goes back to the body at the next chapter that is not supplementary, or at a book part divider,
--- and the heading counter is restored from the body mark, so the next body chapter keeps the body numbering.
--- When it goes back to the body, a carry mark keeps the supplementary counters.
--- A later run of supplementary chapters resumes from that mark, with the heading counter,
--- then restores the float and equation counters after its heading,
--- so every supplementary chapter of the book shares one `S1`, `S2` sequence.
---
--- Example: a book with the chapters `Intro`, `Data {.supplementary}`, `More {.supplementary}` and `End`
--- gives these top-level blocks, where `(heading)` stands for the chapter heading:
---
---     (Intro)
---     #typst-extras-body-mark()                  -- keeps the heading counter of the body: (1,)
---     #typst-extras-part-start("supplementary", ..)
---     (Data)                                     -- reads S1
---     #typst-extras-carry-mark()                 -- keeps the float and equation counters of S1
---     (More)                                     -- reads S2; the book resets the float counters here
---     #typst-extras-carry-restore(..)            -- so they are restored from the carry mark
---     #typst-extras-carry-mark()                 -- keeps the counters of the run, for a later run
---     #typst-extras-body-restore()               -- back to the body, heading counter (1,)
---     (End)                                      -- reads 2
--- @param blocks pandoc.Blocks The top-level blocks of the book
--- @param kinds string[] Figure kinds to reset, from `sections.kinds`
--- @return pandoc.Blocks blocks The blocks, with the part changes inserted
--- @return boolean marked Whether the book has a supplementary chapter
function M.mark_book(blocks, kinds)
  local top = top_level(blocks)
  local result = pandoc.Blocks({})
  local marked = false
  local in_supplementary = false
  local function leave_supplementary()
    if in_supplementary then
      result:insert(pandoc.RawBlock('typst', '#typst-extras-carry-mark()'))
      result:insert(pandoc.RawBlock('typst', '#typst-extras-body-restore()'))
      in_supplementary = false
    end
  end
  local carry = pandoc.RawBlock('typst', '#typst-extras-carry-restore(' .. kinds_module.typst_array(kinds) .. ')')
  for _, block in ipairs(blocks) do
    local divider = book_divider(block)
    local follow = nil
    if block.t == 'Header' and block.level == top then
      local part = top_part_of(block)
      if part == 'supplementary' then
        if in_supplementary then
          result:insert(pandoc.RawBlock('typst', '#typst-extras-carry-mark()'))
          follow = carry
        elseif marked then
          result:insert(pandoc.RawBlock('typst', '#typst-extras-body-mark()'))
          result:insert(pandoc.RawBlock('typst', '#typst-extras-part-resume("supplementary")'))
          follow = carry
        else
          result:insert(pandoc.RawBlock('typst', '#typst-extras-body-mark()'))
          result:insert(M.part_start(part, kinds))
        end
        block.classes = block.classes:filter(function(class) return class ~= part end)
        in_supplementary = true
        marked = true
      else
        if part == 'appendix' then
          options.warn(MODULE_NAME, 'the .appendix class does nothing in a book, so "' ..
            pandoc.utils.stringify(block) .. '" stays a chapter: use the book\'s appendices: list.')
        end
        leave_supplementary()
      end
    elseif divider then
      leave_supplementary()
    elseif block.t == 'Header' and part_of(block) then
      warn_deep(block, DEEP_BOOK_ADVICE)
    end
    result:insert(block)
    if follow then
      result:insert(follow)
    end
  end
  return result, marked
end

return M
