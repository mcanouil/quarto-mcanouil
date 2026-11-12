--- @module "authors"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Author display data for Typst
--- @description Reads the authors and affiliations that Quarto normalises
--- (`authors` and `affiliations`) and delivers them to Typst as the
--- `mcanouil-authors` metadata: one record for each author, with the number of
--- each affiliation, and the list of affiliation lines. For HTML, it builds the
--- same display as markup for the title block.

local fail = require('lib.fail')
local labels = require('lib.labels')

--- @type string Directory of the extension, the parent of `lua/`.
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\][^/\\]+$')

local str = dofile(EXTENSION_DIR .. '/_vendor/quarto-lua-modules/string.lua')

local M = {}

--- @type string[] Address fields of an affiliation, in display order.
M.AFFILIATION_FIELDS = { 'name', 'department', 'address', 'city', 'region', 'postal-code', 'country' }

--- Answer a metadata value as text.
--- @param value any Metadata value, or nil
--- @return string Text, empty for nil
local function text(value)
  return value == nil and '' or pandoc.utils.stringify(value)
end

--- Answer whether an attribute of an author is true.
--- @param author table Author metadata
--- @param key string Attribute name, for example `corresponding`
--- @return boolean
local function flag(author, key)
  local value = author.attributes and author.attributes[key]
  return value == true or text(value) == 'true'
end

--- Answer the display name of an author.
--- @param author table Author metadata
--- @return string Name
local function name_of(author)
  local name = author.name
  if pandoc.utils.type(name) == 'table' or pandoc.utils.type(name) == 'Meta' then
    if name.literal ~= nil then
      return text(name.literal)
    end
    return (text(name.given) .. ' ' .. text(name.family)):gsub('^%s+', ''):gsub('%s+$', '')
  end
  return text(name)
end

--- Answer the one line description of an affiliation.
--- @param affiliation table Affiliation metadata
--- @return string Line, for example `Inserm U1283, Lille, France`
local function affiliation_line(affiliation)
  local parts = {}
  for _, field in ipairs(M.AFFILIATION_FIELDS) do
    local part = text(affiliation[field])
    if part ~= '' then
      parts[#parts + 1] = part
    end
  end
  return table.concat(parts, ', ')
end

--- @type string Separator that the CRediT terms put in a role, such as `writing – original draft`.
local CREDIT_SEPARATOR = ' \u{2013} '

--- Answer a role term for display: the separator of the CRediT terms becomes a comma.
--- @param term string
--- @return string
local function role_label(term)
  return (term:gsub(CREDIT_SEPARATOR, ', '))
end

--- Answer the CRediT roles of an author, each with its degree of contribution.
--- @param author table Author metadata
--- @return table[] Roles: `role` is the term, `degree` is `lead`, `equal`, `supporting` or `''`
local function roles_of(author)
  local roles = {}
  for _, entry in ipairs(author.roles or {}) do
    if pandoc.utils.type(entry) == 'Inlines' then
      roles[#roles + 1] = { role = role_label(text(entry)), degree = '' }
    else
      roles[#roles + 1] = {
        role = role_label(text(entry['vocab-term'] or entry.role)),
        degree = text(entry['degree-of-contribution']):lower(),
      }
    end
  end
  return roles
end

--- Read the authors of a document.
--- @param meta table Document metadata, after Quarto normalised the authors
--- @return table|nil `authors`, `affiliations` (lines) and `email` of the corresponding author, or nil without authors
function M.collect(meta)
  if meta.authors == nil or #meta.authors == 0 then
    return nil
  end
  local numbers, lines = {}, {}
  for index, affiliation in ipairs(meta.affiliations or {}) do
    numbers[text(affiliation.id)] = tonumber(text(affiliation.number)) or index
    lines[tonumber(text(affiliation.number)) or index] = affiliation_line(affiliation)
  end
  local result = { authors = {}, affiliations = lines, email = '' }
  for _, author in ipairs(meta.authors) do
    local degrees, affiliations = {}, {}
    for _, degree in ipairs(author.degrees or {}) do
      degrees[#degrees + 1] = text(degree)
    end
    for _, reference in ipairs(author.affiliations or {}) do
      local number = numbers[text(reference.ref)]
      if number ~= nil then
        affiliations[#affiliations + 1] = number
      end
    end
    local record = {
      name = name_of(author),
      degrees = degrees,
      affiliations = affiliations,
      orcid = text(author.orcid),
      email = text(author.email),
      corresponding = flag(author, 'corresponding'),
      equal = flag(author, 'equal-contributor'),
      deceased = flag(author, 'deceased'),
      roles = roles_of(author),
    }
    if record.corresponding and result.email == '' then
      result.email = text(author.email)
    end
    result.authors[#result.authors + 1] = record
  end
  return result
end

--- Format a list as a Typst array. A trailing comma keeps a single element an array.
--- @param items string[] Typst values
--- @return string Typst array
local function array(items)
  return '(' .. table.concat(items, ', ') .. (#items > 0 and ',' or '') .. ')'
end

--- Format the collected authors as a Typst value.
--- @param collected table Result of `M.collect`
--- @return string Typst dictionary with `authors`, `affiliations` and `email`
function M.typst(collected)
  local quote = labels.typst_string
  local people = {}
  for _, author in ipairs(collected.authors) do
    local degrees = {}
    for _, degree in ipairs(author.degrees) do
      degrees[#degrees + 1] = quote(degree)
    end
    local numbers = {}
    for _, number in ipairs(author.affiliations) do
      numbers[#numbers + 1] = tostring(number)
    end
    local roles = {}
    for _, role in ipairs(author.roles or {}) do
      roles[#roles + 1] = string.format('(role: %s, degree: %s)', quote(role.role), quote(role.degree))
    end
    people[#people + 1] = table.concat({
      '(name: ', quote(author.name),
      ', degrees: ', array(degrees),
      ', affiliations: ', array(numbers),
      ', orcid: ', quote(author.orcid),
      ', email: ', quote(author.email or ''),
      ', corresponding: ', tostring(author.corresponding),
      ', equal: ', tostring(author.equal),
      ', deceased: ', tostring(author.deceased),
      ', roles: ', array(roles), ')',
    })
  end
  local lines = {}
  for _, line in ipairs(collected.affiliations) do
    lines[#lines + 1] = quote(line)
  end
  return table.concat({
    '(authors: ', array(people),
    ', affiliations: ', array(lines),
    ', email: ', quote(collected.email), ')',
  })
end

--- @type string Path data of the ORCID disc, in a 32 by 32 view box.
local ORCID_DISC = 'M32 16c0 8.837-7.163 16-16 16-8.838 0-16-7.163-16-16C0 7.162 7.162 0 16 0c8.837 0 16 7.162 16 16Z'

--- @type string Path data of the ORCID glyph, in a 32 by 32 view box.
local ORCID_GLYPH = 'M18.813 9.637h-5.45v13.9h5.474c4.555 0 7.35-3.378 7.35-6.95 0-1.635-.562-3.372-1.77-4.704-1.215-1.336-3.065-2.246-5.605-2.246ZM18.6 21.3h-2.813v-9.425H18.5c1.823 0 3.12.552 3.96 1.4.842.849 1.252 2.021 1.252 3.312 0 .784-.239 1.967-.993 2.948-.745.969-2.01 1.765-4.119 1.765ZM8.363 9.675v13.887h2.425V9.675H8.363ZM9.575 8.65c.84 0 1.513-.689 1.513-1.513 0-.823-.673-1.512-1.513-1.512-.838 0-1.512.674-1.512 1.513 0 .823.672 1.512 1.512 1.512Z'

--- @type table<string, string> Visible mark of each author attribute, hidden from screen readers.
local HTML_MARKS = {
  corresponding = '\u{2709}\u{FE0E}',
  equal = '*',
  deceased = '\u{2020}',
}

--- @type table<string, string> Label key of each author attribute.
local MARK_LABELS = {
  corresponding = 'mcanouil-author-corresponding',
  equal = 'mcanouil-author-equal',
  deceased = 'mcanouil-author-deceased',
}

--- @type string[] Author attributes, in display order.
local MARK_ORDER = { 'corresponding', 'equal', 'deceased' }

--- Answer a mark that screen readers read as its label.
--- @param mark string Attribute name, for example `corresponding`
--- @param label fun(key: string): string Label lookup
--- @return string HTML
local function html_mark(mark, label)
  return '<span class="mc-author-mark mc-author-' .. mark .. '"><span aria-hidden="true">'
    .. HTML_MARKS[mark] .. '</span><span class="visually-hidden">' .. str.escape_html(label(MARK_LABELS[mark]))
    .. '</span></span>'
end

--- Answer the ORCID link of an author, with a name that reads "ORCID <id>".
--- @param orcid string ORCID identifier
--- @param label fun(key: string): string Label lookup
--- @return string HTML
local function html_orcid(orcid, label)
  local id = str.escape_attribute(orcid)
  return '<a class="mc-orcid" href="https://orcid.org/' .. id .. '" aria-label="'
    .. str.escape_attribute(label('mcanouil-author-orcid')) .. ' ' .. id .. '">'
    .. '<svg viewBox="0 0 32 32" aria-hidden="true" focusable="false">'
    .. '<path class="mc-orcid-disc" d="' .. ORCID_DISC .. '"/>'
    .. '<path class="mc-orcid-glyph" fill-rule="evenodd" d="' .. ORCID_GLYPH .. '"/></svg></a>'
end

--- Answer the markup of one author: the name, the degrees in small type, the
--- affiliation numbers, the marks and the ORCID link.
--- @param author table Author record from `M.collect`
--- @param label fun(key: string): string Label lookup
--- @return string HTML
local function html_author(author, label)
  local parts = { '<span class="mc-author-name">' .. str.escape_html(author.name) .. '</span>' }
  if #author.degrees > 0 then
    parts[#parts + 1] = '<span class="mc-author-degrees">' .. str.escape_html(table.concat(author.degrees, ', ')) .. '</span>'
  end
  if #author.affiliations > 0 then
    local numbers = {}
    for _, number in ipairs(author.affiliations) do
      numbers[#numbers + 1] = tostring(number)
    end
    parts[#parts + 1] = '<sup class="mc-author-affiliations">' .. table.concat(numbers, ',') .. '</sup>'
  end
  for _, mark in ipairs(MARK_ORDER) do
    if author[mark] then
      parts[#parts + 1] = html_mark(mark, label)
    end
  end
  if author.orcid ~= '' then
    parts[#parts + 1] = html_orcid(author.orcid, label)
  end
  return '<span class="mc-author">' .. table.concat(parts) .. '</span>'
end

--- Answer the legend lines of the marks that the authors use.
--- @param collected table Result of `M.collect`
--- @param label fun(key: string): string Label lookup
--- @return string[] Lines, as HTML
local function html_legends(collected, label)
  local lines = {}
  for _, mark in ipairs(MARK_ORDER) do
    local used = false
    for _, author in ipairs(collected.authors) do
      used = used or author[mark]
    end
    if used then
      local line = '<span aria-hidden="true">' .. HTML_MARKS[mark] .. '</span> ' .. str.escape_html(label(MARK_LABELS[mark]))
      if mark == 'corresponding' and collected.email ~= '' then
        local email = str.escape_html(collected.email)
        line = line .. ': <a href="mailto:' .. str.escape_attribute(collected.email) .. '">' .. email .. '</a>'
      end
      lines[#lines + 1] = '<li>' .. line .. '</li>'
    end
  end
  return lines
end

--- Answer the author display of the HTML title block: the author line, the
--- numbered affiliations and the legend of the marks, as in the Typst title block.
--- @param collected table Result of `M.collect`
--- @param label fun(key: string): string Label lookup
--- @return string HTML
function M.html(collected, label)
  local people = {}
  for _, author in ipairs(collected.authors) do
    people[#people + 1] = html_author(author, label)
  end
  local blocks = { '<p class="mc-authors">' .. table.concat(people, '<span class="mc-author-separator">, </span>') .. '</p>' }
  if #collected.affiliations > 0 then
    local items = {}
    for number, line in ipairs(collected.affiliations) do
      items[#items + 1] = '<li><sup>' .. number .. '</sup> ' .. str.escape_html(line) .. '</li>'
    end
    blocks[#blocks + 1] = '<ol class="mc-affiliations">' .. table.concat(items) .. '</ol>'
  end
  local legends = html_legends(collected, label)
  if #legends > 0 then
    blocks[#blocks + 1] = '<ul class="mc-author-legends">' .. table.concat(legends) .. '</ul>'
  end
  return table.concat(blocks, '\n')
end

--- @type table<string, string> Mark of each degree of contribution.
M.CREDIT_MARKS = { lead = 'L', equal = 'E', supporting = 'S' }

--- @type string[] Degrees of contribution, in legend order.
local CREDIT_DEGREES = { 'lead', 'equal', 'supporting' }

--- @type string Mark of a role with no degree of contribution.
local CREDIT_CONTRIBUTED = '\u{2022}'

--- Answer the initials of a name, for example `AA` for `Ana Author`.
--- @param name string
--- @return string
local function initials(name)
  local letters = {}
  for word in name:gmatch('%S+') do
    letters[#letters + 1] = pandoc.text.upper(pandoc.text.sub(word, 1, 1))
  end
  return table.concat(letters)
end

--- Answer the CRediT table of the authors: the roles as rows and the authors as columns.
--- @param collected table Result of `M.collect`
--- @param label fun(key: string): string Label of a key in the document language
--- @return table|nil `columns` (initials), `rows` (`role` and `marks`, one mark for each author) and `legend`; nil when no author has a role
function M.credit_matrix(collected, label)
  local columns, rows, index, degrees = {}, {}, {}, {}
  for _, author in ipairs(collected.authors) do
    columns[#columns + 1] = initials(author.name)
  end
  for number, author in ipairs(collected.authors) do
    for _, entry in ipairs(author.roles) do
      if index[entry.role] == nil then
        local marks = {}
        for position = 1, #collected.authors do
          marks[position] = ''
        end
        rows[#rows + 1] = {
          role = pandoc.text.upper(pandoc.text.sub(entry.role, 1, 1)) .. pandoc.text.sub(entry.role, 2),
          marks = marks,
        }
        index[entry.role] = #rows
      end
      rows[index[entry.role]].marks[number] = M.CREDIT_MARKS[entry.degree] or CREDIT_CONTRIBUTED
      degrees[M.CREDIT_MARKS[entry.degree] and entry.degree or CREDIT_CONTRIBUTED] = true
    end
  end
  if #rows == 0 then
    return nil
  end
  local legend = {}
  for _, degree in ipairs(CREDIT_DEGREES) do
    if degrees[degree] then
      legend[#legend + 1] = M.CREDIT_MARKS[degree] .. ' ' .. label('mcanouil-credit-' .. degree)
    end
  end
  if degrees[CREDIT_CONTRIBUTED] then
    legend[#legend + 1] = CREDIT_CONTRIBUTED .. ' ' .. label('mcanouil-credit-contributed')
  end
  return { columns = columns, rows = rows, legend = table.concat(legend, ' \u{b7} ') }
end

--- Answer the blocks of the CRediT table for an HTML document: a heading, the table with header cells for
--- the authors and for the roles, and the legend line.
--- @param matrix table Result of `M.credit_matrix`
--- @param label fun(key: string): string Label of a key in the document language
--- @return pandoc.Blocks
function M.credit_blocks(matrix, label)
  local function cell(text, alignment)
    return pandoc.Cell({ pandoc.Plain({ pandoc.Str(text) }) }, alignment or pandoc.AlignCenter)
  end
  local head = { cell(label('mcanouil-credit-role'), pandoc.AlignLeft) }
  local specs = { { pandoc.AlignLeft, nil } }
  for _, column in ipairs(matrix.columns) do
    head[#head + 1] = cell(column)
    specs[#specs + 1] = { pandoc.AlignCenter, nil }
  end
  local rows = {}
  for _, row in ipairs(matrix.rows) do
    local cells = { cell(row.role, pandoc.AlignLeft) }
    for _, mark in ipairs(row.marks) do
      cells[#cells + 1] = cell(mark)
    end
    rows[#rows + 1] = pandoc.Row(cells)
  end
  local table_block = pandoc.Table(
    pandoc.Caption({}), specs, pandoc.TableHead({ pandoc.Row(head) }),
    { { attr = pandoc.Attr(), row_head_columns = 1, head = {}, body = rows } },
    pandoc.TableFoot()
  )
  return pandoc.Blocks({
    pandoc.Header(1, { pandoc.Str(label('mcanouil-credit-title')) }, pandoc.Attr('credit', { 'unnumbered' })),
    table_block,
    pandoc.Para({ pandoc.Str(matrix.legend) }),
  })
end

--- Deliver the authors to Typst as the `mcanouil-authors` metadata.
--- @param meta table Document metadata
--- @return table Metadata
local function deliver(meta)
  if not quarto.doc.is_format('typst') then
    return meta
  end
  local collected = M.collect(meta)
  if collected ~= nil then
    meta['mcanouil-authors'] = pandoc.MetaInlines({ pandoc.RawInline('typst', M.typst(collected)) })
  end
  return meta
end

--- Append the CRediT table to an HTML article, after the references.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function append_credit_table(doc)
  local options = doc.meta.extensions and doc.meta.extensions.mcanouil or {}
  if not quarto.doc.is_format('html') or quarto.doc.is_format('revealjs') or text(options.type) ~= 'article' then
    return doc
  end
  local collected = M.collect(doc.meta)
  local matrix = collected and M.credit_matrix(collected, labels.get)
  if matrix then
    doc.blocks:extend(M.credit_blocks(matrix, labels.get))
  end
  return doc
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = fail.guard(deliver) }

--- @type table Filter step of the closing filter, after Quarto's own filters.
M.post_filter = { Pandoc = fail.guard(append_credit_table) }

return M
