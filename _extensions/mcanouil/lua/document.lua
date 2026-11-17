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
local labels = require('lib.labels')

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

--- @type table<string, string[]> The document types that Typst renders, with the layouts of each.
M.TYPES = {
  report = { 'compact', 'full' },
  article = { 'standard' },
  memo = { 'standard' },
}

--- @type table<string, string[]> The kinds of the types that vary by kind, the default kind first.
M.KINDS = {
  memo = { 'note', 'minutes', 'agenda', 'brief' },
}

--- @type table<string, string[]> The banner fields of each memo kind, in order. A key names the
--- metadata `extensions.mcanouil.memo.<key>` and the label `mcanouil-memo-<key>`.
M.MEMO_FIELDS = {
  note = { 'to', 'from', 'date' },
  minutes = { 'date-time', 'present', 'absent' },
  agenda = { 'date-time', 'place', 'participants' },
  brief = { 'date', 'audience', 'purpose' },
}

--- @type table<string, table<string, string>> Margin note columns of the types that set one, as the
--- `margin-geometry` metadata of Quarto: the distance to the page edge, the width and the separation
--- from the text, for the inner (left) and outer (right) margin.
M.MARGIN_GEOMETRY = {
  article = {
    inner = { far = '12mm', width = '0mm', separation = '8mm' },
    outer = { far = '8mm', width = '42mm', separation = '8mm' },
    clearance = '12pt',
  },
}

--- @type table<string, table<string, string>> Page margin above and below the text of the types that set a margin note column.
M.MARGIN_VERTICAL = { article = { top = '25mm', bottom = '25mm' } }

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
  article = {
    header = { left = 'title', centre = '', right = '' },
    footer = { left = 'author', centre = 'version', right = 'page' },
  },
  deck = {
    header = { left = '', centre = '', right = '' },
    footer = { left = 'speaker', centre = 'title', right = 'page' },
  },
  memo = {
    header = { left = '', centre = '', right = '' },
    footer = { left = 'author', centre = 'version', right = 'page' },
  },
}

--- @type table<string, string|false> Fields a slot can name. A string is the
--- Typst call that renders the field; `false` means the value comes from the
--- metadata key of the same name, except `author`, and `speaker`: the authors
--- and `extensions.mcanouil.event`, joined by a middle dot.
M.FIELDS = {
  title = false,
  subtitle = false,
  author = false,
  date = false,
  version = false,
  chapter = '#chapter-title()',
  page = '#page-number()',
  speaker = false,
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
--- @param doc_type string|nil Document type; nil reads `extensions.mcanouil.type`
--- @return table `header` and `footer`, each with `left`, `centre` and `right` slots
function M.furniture(meta, doc_type)
  local options = meta.extensions and meta.extensions.mcanouil or {}
  doc_type = doc_type or (options.type and pandoc.utils.stringify(options.type)) or M.DEFAULT_TYPE
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

--- @type integer Most authors that a slot names; with more, it names the first one and "et al.".
M.MAX_SLOT_AUTHORS = 2

--- Answer the author names of a document, joined by commas. With more than
--- `M.MAX_SLOT_AUTHORS` authors, answer the first name and the "et al." label,
--- so the slot stays on one line.
--- @param meta table Document metadata
--- @param et_al string|nil Label that follows the first name; nil reads it in the document language
--- @return pandoc.Inlines Names
local function authors(meta, et_al)
  local value = meta.author
  if value == nil then
    return pandoc.Inlines({})
  end
  local entries = pandoc.utils.type(value) == 'List' and value or { value }
  local names = {}
  for _, entry in ipairs(entries) do
    local name = author_name(entry)
    if name ~= nil and pandoc.utils.stringify(name) ~= '' then
      names[#names + 1] = pandoc.Inlines(name)
    end
  end
  local inlines = pandoc.Inlines({})
  if #names > M.MAX_SLOT_AUTHORS then
    inlines:extend(names[1])
    inlines:extend({ pandoc.Space(), pandoc.Str(et_al or labels.get('mcanouil-et-al')) })
    return inlines
  end
  for index, name in ipairs(names) do
    if index > 1 then
      inlines:extend({ pandoc.Str(','), pandoc.Space() })
    end
    inlines:extend(name)
  end
  return inlines
end

--- Answer the speaker and the event, joined by a middle dot.
--- @param names pandoc.Inlines Author names
--- @param event any|nil Event, as metadata inlines or text
--- @return pandoc.Inlines Content of the slot
function M.speaker_event(names, event)
  local inlines = pandoc.Inlines(names)
  if event ~= nil and pandoc.utils.stringify(event) ~= '' then
    if #inlines > 0 then
      inlines:extend({ pandoc.Space(), pandoc.Str('·'), pandoc.Space() })
    end
    inlines:extend(pandoc.Inlines(event))
  end
  return inlines
end

--- Answer the content of a slot. A field with no value gives empty inlines.
--- @param slot table Slot from `M.furniture`
--- @param meta table Document metadata
--- @param et_al string|nil Label that follows the first of many authors; nil reads it in the document language
--- @return pandoc.Inlines Content
function M.resolve_slot(slot, meta, et_al)
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
    return authors(meta, et_al)
  end
  if slot.value == 'speaker' then
    local options = meta.extensions and meta.extensions.mcanouil or {}
    return M.speaker_event(authors(meta, et_al), options.event)
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
  local layout = option(options, 'layout') or layouts[1]
  if not contains(layouts, layout) then
    return nil, string.format(
      'mcanouil: unknown layout "%s" for type "%s"; use %s.', layout, doc_type, table.concat(layouts, ', ')
    )
  end
  local kind = option(options, 'kind')
  local kinds = M.KINDS[doc_type]
  if kinds then
    kind = kind or kinds[1]
    if not contains(kinds, kind) then
      local sorted = { table.unpack(kinds) }
      table.sort(sorted)
      return nil, string.format(
        'mcanouil: unknown kind "%s" for type "%s"; use %s.', kind, doc_type, table.concat(sorted, ', ')
      )
    end
  end
  return { type = doc_type, layout = layout, kind = kind }
end

--- Answer the value of a memo banner field, in the document metadata.
--- @param meta table Document metadata
--- @param key string Field key
--- @return any|nil Value, or nil when the field is not set or is empty
local function memo_value(meta, key)
  local options = meta.extensions and meta.extensions.mcanouil or {}
  local memo = options.memo or {}
  local sources = {}
  local function add(value)
    if value ~= nil then
      sources[#sources + 1] = value
    end
  end
  add(memo[key])
  if key == 'date-time' then
    add(memo.date)
  end
  if key == 'date' or key == 'date-time' then
    add(meta.date)
  end
  for _, value in ipairs(sources) do
    if pandoc.utils.stringify(value) ~= '' then
      return value
    end
  end
  return nil
end

--- Answer the banner fields of a memo that have a value, in the order of the kind.
--- A field with no value is left out, so the banner has no empty row.
--- @param meta table Document metadata
--- @param kind string Memo kind
--- @return table[] Fields, each with `key` and `value` (inlines)
function M.memo_fields(meta, kind)
  local fields = {}
  for _, key in ipairs(M.MEMO_FIELDS[kind] or {}) do
    local value = memo_value(meta, key)
    if value ~= nil then
      local inlines = pandoc.utils.type(value) == 'Inlines' and value or pandoc.Inlines(pandoc.utils.stringify(value))
      fields[#fields + 1] = { key = key, value = inlines }
    end
  end
  return fields
end

--- Set the margin note column of a document type that has one, so Quarto sets up the margin
--- layout whether or not the document has a margin note.
--- @param meta table Document metadata
--- @param doc_type string Document type
local function deliver_margin(meta, doc_type)
  local geometry = M.MARGIN_GEOMETRY[doc_type]
  if geometry == nil then
    return
  end
  meta['margin-geometry'] = geometry
  meta.margin = meta.margin or M.MARGIN_VERTICAL[doc_type]
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
  deliver_margin(meta, resolved.type)
  if resolved.type == 'memo' then
    local fields = pandoc.List()
    for _, field in ipairs(M.memo_fields(meta, resolved.kind)) do
      fields:insert({ key = pandoc.MetaString(field.key), value = pandoc.MetaInlines(field.value) })
    end
    meta['mcanouil-memo-fields'] = pandoc.MetaList(fields)
  end
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
