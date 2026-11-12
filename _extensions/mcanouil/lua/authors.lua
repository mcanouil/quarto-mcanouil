--- @module "authors"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Author display data for Typst
--- @description Reads the authors and affiliations that Quarto normalises
--- (`authors` and `affiliations`) and delivers them to Typst as the
--- `mcanouil-authors` metadata: one record for each author, with the number of
--- each affiliation, and the list of affiliation lines.

local labels = require('lib.labels')

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
      corresponding = flag(author, 'corresponding'),
      equal = flag(author, 'equal-contributor'),
      deceased = flag(author, 'deceased'),
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
    people[#people + 1] = table.concat({
      '(name: ', quote(author.name),
      ', degrees: ', array(degrees),
      ', affiliations: ', array(numbers),
      ', orcid: ', quote(author.orcid),
      ', corresponding: ', tostring(author.corresponding),
      ', equal: ', tostring(author.equal),
      ', deceased: ', tostring(author.deceased), ')',
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

--- @type table Filter step of the entry filter.
M.filter = { Meta = deliver }

return M
