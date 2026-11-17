--- Typst Extras - Section numbering
--- @module "sections"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Number floats, equations, callouts and theorems by section, and add appendix and supplementary sections.
--- @description With `crossref.chapters: true`, prefixes numbers with the level-1 heading number
---   and resets the counters at each level-1 heading.
---   Sections with the `.appendix` or `.supplementary` class move to the end and get `A.1` or `S1` numbers.
---   In a book, supplementary chapters get `S1` numbers in place, and the book keeps its own numbering.
---   The numbering functions of Quarto are wrapped, not replaced, so other numbering stays as it was.

local options = require(quarto.utils.resolve_path('_modules/options.lua'):gsub('%.lua$', ''))
local emit = require(quarto.utils.resolve_path('_modules/emit.lua'):gsub('%.lua$', ''))
local kinds_module = require(quarto.utils.resolve_path('_modules/kinds.lua'):gsub('%.lua$', ''))
local parts = require(quarto.utils.resolve_path('_modules/parts.lua'):gsub('%.lua$', ''))

local M = {}

--- Name used in messages.
local MODULE_NAME = 'sections'

--- Callout types. Quarto names their figure kinds `quarto-callout-<title>`, from the language key `callout-<type>-title`.
local CALLOUT_TYPES = { 'note', 'tip', 'warning', 'important', 'caution' }

--- Default separator between the appendix label and the title, as in Quarto.
local DEFAULT_APPENDIX_DELIM = ' \u{2014}'

--- Keys accepted in the `sections` block, in the order shown in messages.
local BLOCK_KEYS = { 'appendix-delimiter', 'supplementary-prefix' }

--- Order of the fields of `typst-extras-config`.
local CONFIG_FIELDS = {
  'chapters', 'appendix-delimiter', 'supplementary-prefix', 'appendix-title', 'appendix-delim', 'number-sections',
  'section-prefix', 'chapter-prefix',
}

--- Read a string from a metadata map, or return the fallback.
--- @param map any A pandoc metadata map, or nil
--- @param key string
--- @param fallback string
--- @return string
local function meta_string(map, key, fallback)
  if pandoc.utils.type(map) ~= 'table' or map[key] == nil then
    return fallback
  end
  return pandoc.utils.stringify(map[key])
end

--- Read a string option of the `sections` block, and stop the render when it is not a string.
--- @param block table The normalised `sections` block
--- @param key string
--- @param fallback string
--- @return string
local function option_string(block, key, fallback)
  local value = block[key]
  if value == nil then
    return fallback
  end
  if type(value) ~= 'string' then
    options.fail(MODULE_NAME, 'unsupported ' .. key .. ' ' .. tostring(value) .. '. Use a string.')
  end
  return value
end

--- Read the section settings from the metadata and the options.
--- `number-sections` comes from the writer options, because Quarto does not keep it in the metadata.
--- `section-prefix` and `chapter-prefix` are the supplements Quarto writes for `@sec-x`, on a section or a chapter,
--- so the reference rule can tell them from a custom supplement.
--- @param meta pandoc.Meta The document metadata
--- @param config table The normalised `typst-extras` options
--- @return table Settings with the fields of `typst-extras-config`
function M.settings(meta, config)
  local crossref = meta.crossref
  local block = config.sections
  if block == nil then
    block = {}
  end
  if type(block) ~= 'table' or options.is_list(block) then
    local shown = options.is_list(block) and 'a list' or tostring(block)
    options.fail(MODULE_NAME, 'unsupported value ' .. shown .. '. Use a map with ' ..
      table.concat(BLOCK_KEYS, ', ') .. '.')
  end
  options.check_keys(MODULE_NAME, block, BLOCK_KEYS)
  local language = quarto.doc.language or {}
  return {
    chapters = pandoc.utils.type(crossref) == 'table' and crossref.chapters == true,
    ['appendix-delimiter'] = option_string(block, 'appendix-delimiter', '.'),
    ['supplementary-prefix'] = option_string(block, 'supplementary-prefix', 'S'),
    ['appendix-title'] = meta_string(crossref, 'appendix-title', language['crossref-apx-prefix'] or 'Appendix'),
    ['appendix-delim'] = meta_string(crossref, 'appendix-delim', DEFAULT_APPENDIX_DELIM),
    ['number-sections'] = PANDOC_WRITER_OPTIONS ~= nil and PANDOC_WRITER_OPTIONS.number_sections == true,
    ['section-prefix'] = meta_string(crossref, 'sec-prefix', language['crossref-sec-prefix'] or 'Section'),
    ['chapter-prefix'] = meta_string(crossref, 'ch-prefix', language['crossref-ch-prefix'] or 'Chapter'),
  }
end

--- Write the settings as a Typst dictionary.
--- @param settings table
--- @return string
function M.config_literal(settings)
  local parts = {}
  for _, field in ipairs(CONFIG_FIELDS) do
    local value = settings[field]
    local text = type(value) == 'boolean' and tostring(value) or emit.string(value)
    parts[#parts + 1] = field .. ': ' .. text
  end
  return '(' .. table.concat(parts, ', ') .. ')'
end

--- List the figure kinds whose counters restart at each chapter.
--- @param meta pandoc.Meta The document metadata
--- @return string[] Built-in floats, custom floats alphabetically, then callouts
function M.kinds(meta)
  local kinds = {}
  for _, key in ipairs(kinds_module.BUILTIN) do
    kinds[#kinds + 1] = kinds_module.FLOAT_PREFIX .. key
  end
  local custom = {}
  for name in pairs(kinds_module.custom(meta)) do
    custom[#custom + 1] = name
  end
  table.sort(custom)
  for _, name in ipairs(custom) do
    kinds[#kinds + 1] = kinds_module.FLOAT_PREFIX .. name
  end
  local language = quarto.doc.language or {}
  for _, callout in ipairs(CALLOUT_TYPES) do
    local title = language['callout-' .. callout .. '-title'] or (callout:sub(1, 1):upper() .. callout:sub(2))
    kinds[#kinds + 1] = 'quarto-callout-' .. title
  end
  return kinds
end

--- Tell whether a heading gets a counter reset by default: every heading without `.unnumbered`.
--- @param header pandoc.Header
--- @return boolean
local function numbered_heading(header)
  return not header.classes:includes('unnumbered')
end

--- Insert a counter reset before top-level headings.
--- The Typst side resets only when the next heading is a numbered level-1 heading,
--- because Pandoc applies `shift-heading-level-by` after the filters, so the level is not known here.
--- Only top-level blocks are scanned, as for appendix and supplementary sections.
--- @param doc pandoc.Pandoc
--- @param kinds string[] Figure kinds to reset, from `M.kinds`
--- @param should_reset (fun(header: pandoc.Header): boolean)|nil Which headings get a reset.
---   Defaults to every heading without `.unnumbered`.
--- @return pandoc.Pandoc
function M.insert_resets(doc, kinds, should_reset)
  should_reset = should_reset or numbered_heading
  local reset = '#typst-extras-reset-chapter(' .. kinds_module.typst_array(kinds) .. ')'
  local blocks = pandoc.Blocks({})
  for _, block in ipairs(doc.blocks) do
    if block.t == 'Header' and should_reset(block) then
      blocks:insert(pandoc.RawBlock('typst', reset))
    end
    blocks:insert(block)
  end
  doc.blocks = blocks
  return doc
end

--- Tell whether body numbers get the chapter prefix.
--- That needs `crossref.chapters`, `number-sections`, and a document that is not a book,
--- because books number chapters themselves.
--- @param meta pandoc.Meta The document metadata
--- @param settings table Settings from `M.settings`
--- @return boolean
function M.chapters_active(meta, settings)
  return settings.chapters and settings['number-sections'] and meta.book == nil
end

--- Emit the Typst side of section-aware numbering: the library, the `typst-extras-config` binding,
--- the wrapped `equation-numbering`, `callout-numbering` and `theorem-numbering` in the header,
--- and, in include-before, the config state update and the figure numbering rule.
--- The figure rule wraps the figure numbering in force at the start of the body,
--- so a template that sets it in its own function, such as a book, keeps it wherever the prefix is empty.
--- Call it at most once per render, from any part of the module that needs prefixed numbers
--- (chapters, appendix or supplementary sections).
--- The wraps keep Quarto's numbering wherever `typst-extras-prefix()` is empty,
--- so the body stays flat when `settings.chapters` is false.
--- @param settings table Settings from `M.settings`. `chapters` is written as given,
---   so set it to `false` when body numbers must stay flat.
--- @param opts table|nil `inherit_theorem_levels` (boolean): also bind `theorem-inherited-levels = 1`,
---   so theorion restarts theorem numbers at each level-1 heading.
---   `parts` (boolean): also add the reference rule for appendix and supplementary headings.
---   `book` (boolean): also wrap the heading numbering of the book, so supplementary chapters read `S1`.
function M.emit_numbering(settings, opts)
  opts = opts or {}
  local header = {
    '#let typst-extras-config = ' .. M.config_literal(settings),
    '#let equation-numbering = typst-extras-wrap(equation-numbering, "(1)")',
    '#let callout-numbering = typst-extras-wrap(callout-numbering, "1")',
  }
  if opts.inherit_theorem_levels then
    header[#header + 1] = '#let theorem-inherited-levels = 1'
  end
  header[#header + 1] = '#let theorem-numbering = typst-extras-wrap-theorem(theorem-numbering, "1")'
  header[#header + 1] = ''
  local before = {
    '#typst-extras-config-state.update(typst-extras-config)',
    '#show: body => context { set figure(numbering: typst-extras-wrap(figure.numbering, "1")); body }',
  }
  if opts.parts then
    before[#before + 1] = '#show ref: typst-extras-ref'
  end
  if opts.book then
    before[#before + 1] = '#show: body => context { set heading(numbering: ' ..
      'typst-extras-book-heading-numbering(heading.numbering, config: typst-extras-config)); body }'
  end
  before[#before + 1] = ''
  emit.library()
  emit.header(table.concat(header, '\n'))
  emit.before_body(table.concat(before, '\n'))
end

--- Tell whether body numbers get the chapter prefix, and warn when `crossref.chapters` cannot apply.
--- @param meta pandoc.Meta The document metadata
--- @param settings table Settings from `M.settings`
--- @return boolean
local function chapters_checked(meta, settings)
  local active = M.chapters_active(meta, settings)
  if not active and settings.chapters and meta.book == nil then
    options.warn(MODULE_NAME, 'crossref.chapters needs number-sections: true to prefix numbers with the ' ..
      'chapter number. Numbers stay flat. Set number-sections: true to number by chapter.')
  end
  return active
end

--- Number floats, equations, callouts and theorems by chapter, when `crossref.chapters` is on.
--- Books number chapters themselves, so a book is left as it is.
--- @param doc pandoc.Pandoc The document
--- @param config table The normalised `typst-extras` options
--- @return pandoc.Pandoc
function M.numbering(doc, config)
  local settings = M.settings(doc.meta, config)
  if not chapters_checked(doc.meta, settings) then
    return doc
  end
  M.emit_numbering(settings, { inherit_theorem_levels = true })
  return M.insert_resets(doc, M.kinds(doc.meta))
end

--- Number the supplementary chapters of a book with `S1`, and leave the rest to the book.
--- The book numbers chapters and appendices, so the body stays as the book makes it.
--- @param doc pandoc.Pandoc The book
--- @param config table The normalised `typst-extras` options
--- @return pandoc.Pandoc doc
--- @return boolean marked Whether the book has a supplementary chapter
local function special_book(doc, config)
  local settings = M.settings(doc.meta, config)
  local blocks, marked = parts.mark_book(doc.blocks, M.kinds(doc.meta))
  if not marked then
    return doc, false
  end
  settings.chapters = false
  M.emit_numbering(settings, { parts = true, book = true })
  doc.blocks = blocks
  return doc, true
end

--- Move appendix and supplementary sections to the end of the document, and number them.
--- When `crossref.chapters` also applies, the body is numbered by chapter here,
--- so that the numbering is emitted once.
--- In a book, nothing moves: supplementary chapters get `S1` numbering in place.
--- @param doc pandoc.Pandoc The document
--- @param config table The normalised `typst-extras` options
--- @return pandoc.Pandoc doc
--- @return boolean moved Whether the document has appendix or supplementary sections
function M.special(doc, config)
  if doc.meta.book ~= nil then
    return special_book(doc, config)
  end
  local settings = M.settings(doc.meta, config)
  local kinds = M.kinds(doc.meta)
  local body, tail = parts.move(doc.blocks, settings, kinds)
  if tail == nil then
    return doc, false
  end
  local chapters = chapters_checked(doc.meta, settings)
  if chapters then
    body = M.insert_resets(pandoc.Pandoc(body, doc.meta), kinds).blocks
  end
  settings.chapters = chapters
  M.emit_numbering(settings, { inherit_theorem_levels = chapters, parts = true })
  body:extend(tail)
  doc.blocks = body
  return doc, true
end

--- Apply the sections module.
--- @param doc pandoc.Pandoc The document
--- @param config table The normalised `typst-extras` options
--- @return pandoc.Pandoc
function M.apply(doc, config)
  local moved
  doc, moved = M.special(doc, config)
  if moved then
    return doc
  end
  return M.numbering(doc, config)
end

return M
