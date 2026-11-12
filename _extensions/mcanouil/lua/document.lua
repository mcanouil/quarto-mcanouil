--- @module "document"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Document type and page furniture
--- @description Reads `extensions.mcanouil.type`, `layout` and `kind`, stops the
--- render for a type that the format cannot render, and delivers the choice to
--- Typst. Reads `extensions.mcanouil.header` and `extensions.mcanouil.footer`,
--- fills the slots the user leaves out from the defaults of the document type,
--- and delivers the resolved content of each slot to Typst.

local fail = require('lib.fail')

local M = {}

--- @type string[] Slot names, in output order.
M.SLOTS = { 'left', 'centre', 'right' }

--- @type table<string, boolean> Slot names, as a set.
local SLOT_NAMES = { left = true, centre = true, right = true }

--- @type string[] Furniture parts.
M.PARTS = { 'header', 'footer' }

--- @type table<string, string> Other spellings of a slot name.
local ALIASES = { center = 'centre' }

--- @type string Document type used when `extensions.mcanouil.type` is not set.
M.DEFAULT_TYPE = 'report'

--- @type string Layout used when `extensions.mcanouil.layout` is not set.
M.DEFAULT_LAYOUT = 'compact'

--- @type table<string, string[]> The document types that Typst renders, with the layouts of each.
M.TYPES = {
  report = { 'compact' },
}

--- @type string[] Document types that only `mcanouil-typst` renders.
M.PDF_ONLY = { 'letter', 'invoice' }

--- @type string The only format that renders a PDF-only type.
local PDF_FORMAT = 'mcanouil-typst'

--- @type table<string, string> Format name of each Quarto output format.
local FORMAT_NAMES = { typst = 'mcanouil-typst', revealjs = 'mcanouil-revealjs', html = 'mcanouil-html' }

--- @type table<string, table> Default slots of each document type, one row
--- per type. A value is a field name, or `''` for an empty slot.
M.DEFAULTS = {
  report = {
    header = { left = 'title', centre = '', right = 'chapter' },
    footer = { left = 'author', centre = 'version', right = 'page' },
  },
}

--- @type table<string, string|false> Fields a slot can name. A string is the
--- Typst call that renders the field; `false` means the value comes from the
--- metadata key of the same name.
M.FIELDS = {
  title = false,
  subtitle = false,
  author = false,
  date = false,
  version = false,
  chapter = '#chapter-title()',
  page = '#page-number()',
}

--- Read a slot value from the metadata.
--- @param value any Metadata value, or a field name from the defaults
--- @return table Slot: `kind` is `field`, `text` or `empty`, and `value` the field name or the inlines
local function read_slot(value)
  local text = type(value) == 'string' and value or pandoc.utils.stringify(value)
  if text == '' then
    return { kind = 'empty' }
  end
  if M.FIELDS[text] ~= nil then
    return { kind = 'field', value = text }
  end
  local inlines = pandoc.utils.type(value) == 'Inlines' and value or pandoc.Inlines(value)
  return { kind = 'text', value = inlines }
end

--- Read the user slots of one part, with the `center` alias.
--- @param part string `header` or `footer`
--- @param options table|nil User value of `extensions.mcanouil.<part>`
--- @return table<string, any> Metadata value of each slot the user sets
local function user_slots(part, options)
  local slots = {}
  if options == nil then
    return slots
  end
  for key, value in pairs(options) do
    local slot = ALIASES[key] or key
    if not SLOT_NAMES[slot] then
      fail.raise(string.format(
        'mcanouil: unknown slot "%s.%s" in extensions.mcanouil; use left, centre (or center) and right.',
        part, key
      ))
    end
    if slots[slot] ~= nil then
      fail.raise(string.format(
        'mcanouil: both "%s.centre" and "%s.center" are set in extensions.mcanouil; keep one.',
        part, part
      ))
    end
    slots[slot] = value
  end
  return slots
end

--- Answer the header and footer slots of a document: the user value of each
--- slot, or the default of the document type.
--- @param meta table Document metadata
--- @return table `header` and `footer`, each with `left`, `centre` and `right` slots
function M.furniture(meta)
  local options = meta.extensions and meta.extensions.mcanouil or {}
  local doc_type = options.type and pandoc.utils.stringify(options.type) or M.DEFAULT_TYPE
  local defaults = M.DEFAULTS[doc_type] or M.DEFAULTS[M.DEFAULT_TYPE]
  local furniture = {}
  for _, part in ipairs(M.PARTS) do
    local user = user_slots(part, options[part])
    furniture[part] = {}
    for _, slot in ipairs(M.SLOTS) do
      local value = user[slot]
      if value == nil then
        value = defaults[part][slot]
      end
      furniture[part][slot] = read_slot(value)
    end
  end
  return furniture
end

--- Answer the display name of one author entry.
--- @param entry any Author metadata: inlines, or a map with `name`
--- @return string|any Name inlines, or nil
local function author_name(entry)
  if pandoc.utils.type(entry) == 'table' and entry.name ~= nil then
    local name = entry.name
    if pandoc.utils.type(name) == 'table' and name.literal ~= nil then
      return name.literal
    end
    return name
  end
  return entry
end

--- Answer the author names of a document, joined by commas.
--- @param meta table Document metadata
--- @return pandoc.Inlines Names
local function authors(meta)
  local value = meta.author
  local inlines = pandoc.Inlines({})
  if value == nil then
    return inlines
  end
  local entries = pandoc.utils.type(value) == 'List' and value or { value }
  for _, entry in ipairs(entries) do
    local name = author_name(entry)
    if name ~= nil and pandoc.utils.stringify(name) ~= '' then
      if #inlines > 0 then
        inlines:extend({ pandoc.Str(','), pandoc.Space() })
      end
      inlines:extend(pandoc.Inlines(name))
    end
  end
  return inlines
end

--- Answer the content of a slot. A field with no value gives empty inlines.
--- @param slot table Slot from `M.furniture`
--- @param meta table Document metadata
--- @return pandoc.Inlines Content
function M.resolve_slot(slot, meta)
  if slot.kind == 'empty' then
    return pandoc.Inlines({})
  end
  if slot.kind == 'text' then
    return slot.value
  end
  local call = M.FIELDS[slot.value]
  if call then
    return pandoc.Inlines({ pandoc.RawInline('typst', call) })
  end
  if slot.value == 'author' then
    return authors(meta)
  end
  local value = meta[slot.value]
  if value == nil then
    return pandoc.Inlines({})
  end
  return pandoc.Inlines(value)
end

--- Read a string option of the extension.
--- @param options table `extensions.mcanouil`
--- @param key string Option name
--- @return string|nil Value, or nil when the option is not set
local function option(options, key)
  local value = options[key]
  if value == nil then
    return nil
  end
  local text = pandoc.utils.stringify(value)
  return text ~= '' and text or nil
end

--- @param list string[]
--- @param value string
--- @return boolean
local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

--- @param map table<string, any>
--- @return string[] Sorted keys
local function sorted_keys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

--- Answer the document type, layout and kind of a document for a format.
--- Quarto replaces the global `error` with a logger that returns, so a failure
--- is returned and the caller stops the render.
--- @param meta table Document metadata
--- @param format string `mcanouil-typst`, `mcanouil-html` or `mcanouil-revealjs`
--- @return table|nil `type`, `layout` and `kind`; `layout` and `kind` are nil when unset or unused
--- @return string|nil Message, when the format cannot render the type or the type or layout is not known
function M.resolve(meta, format)
  local options = meta.extensions and meta.extensions.mcanouil or {}
  local doc_type = option(options, 'type')
  if doc_type and format ~= PDF_FORMAT and contains(M.PDF_ONLY, doc_type) then
    return nil, string.format('mcanouil: type "%s" supports %s only, not %s.', doc_type, PDF_FORMAT, format)
  end
  if format == 'mcanouil-revealjs' then
    return { type = doc_type == 'workshop' and 'workshop' or 'deck' }
  end
  doc_type = doc_type or M.DEFAULT_TYPE
  local layouts = M.TYPES[doc_type]
  if not layouts then
    return nil, string.format('mcanouil: unknown type "%s"; use %s.', doc_type, table.concat(sorted_keys(M.TYPES), ', '))
  end
  local layout = option(options, 'layout') or M.DEFAULT_LAYOUT
  if not contains(layouts, layout) then
    return nil, string.format(
      'mcanouil: unknown layout "%s" for type "%s"; use %s.', layout, doc_type, table.concat(layouts, ', ')
    )
  end
  return { type = doc_type, layout = layout, kind = option(options, 'kind') }
end

--- Deliver the type and the resolved slots to Typst as `mcanouil-type`,
--- `mcanouil-layout`, `mcanouil-kind`, `mcanouil-header` and `mcanouil-footer`.
--- Stops the render, with a message, when the type cannot be rendered.
--- @param meta table Document metadata
--- @return table Metadata
local function deliver(meta)
  local format = quarto.doc.is_format('typst') and FORMAT_NAMES.typst
    or quarto.doc.is_format('revealjs') and FORMAT_NAMES.revealjs
    or FORMAT_NAMES.html
  local resolved, message = M.resolve(meta, format)
  if not resolved then
    fail.stop(message)
  end
  if format ~= FORMAT_NAMES.typst then
    return meta
  end
  meta['mcanouil-type'] = resolved.type
  meta['mcanouil-layout'] = resolved.layout
  meta['mcanouil-kind'] = resolved.kind
  local furniture = M.furniture(meta)
  for _, part in ipairs(M.PARTS) do
    local delivered = {}
    for _, slot in ipairs(M.SLOTS) do
      delivered[slot] = pandoc.MetaInlines(M.resolve_slot(furniture[part][slot], meta))
    end
    meta['mcanouil-' .. part] = delivered
  end
  return meta
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = fail.guard(deliver) }

return M
