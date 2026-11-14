--- @module "workshop"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Blocks and solutions of the workshop type
--- @description Rewrites the blocks of a workshop session (`.objectives`,
--- `.prerequisites`, `.exercise`, `.solution` inside an exercise, and
--- `.checkpoint`) for the output format. Each block gets a visible label from
--- the language files, so it never relies on colour alone. An exercise label
--- holds its number (with the session number when it is set), its `duration`
--- and its `format`; a solution label holds its `name`. Quarto reads a
--- solution as a `Proof` node; the workshop step turns it back into a division
--- that keeps its content, identifier, classes and other attributes. A
--- solution is a native `<details>` disclosure in HTML, a block of the veil
--- group `solutions`, hidden until shown, in Reveal.js, and in Typst, after
--- `extensions.mcanouil.solutions`: collected at the end behind a "Solution:
--- page n" link (`end`, the default), in its exercise (`inline`), or left out
--- (`hide`). A reference to a solution identifier, such as `@sol-a`, links to
--- the solution with its label, "Solution 2.1".

local fail = require('lib.fail')
local labels = require('lib.labels')
local document = require('document')

local M = {}

--- @type string[] Values of `extensions.mcanouil.solutions`, the default first.
M.MODES = { 'end', 'inline', 'hide' }

--- @type string Veil group of the solutions of a deck.
M.GROUP = 'solutions'

--- @type table<string, string> Label key of each block that is not an exercise or a solution.
M.LABELS = {
  objectives = 'mcanouil-objectives',
  prerequisites = 'mcanouil-prerequisites',
  checkpoint = 'mcanouil-checkpoint',
}

--- @type string Separator between the parts of an exercise label.
local SEPARATOR = ' · '

--- Answer an option of `extensions.mcanouil` as text.
--- @param meta table Document metadata
--- @param key string Option name
--- @return string|nil Text, or nil when the option is not set or is empty
local function option(meta, key)
  local options = meta.extensions and meta.extensions.mcanouil or {}
  if options[key] == nil then
    return nil
  end
  local text = pandoc.utils.stringify(options[key])
  return text ~= '' and text or nil
end

--- Answer the text of an attribute, or nil when it is empty.
--- @param value string|nil Attribute value
--- @return string|nil
local function attribute(value)
  return value ~= nil and value ~= '' and value or nil
end

--- Answer the session of a workshop as text: "Session 2 of 7", or "Session 2"
--- when the total is not set.
--- @param meta table Document metadata
--- @return string|nil Text, or nil when the session number is not set
function M.session_text(meta)
  local number = document.session_number(meta)
  if number == nil then
    return nil
  end
  local session = meta.extensions.mcanouil.session
  local total = session.total and pandoc.utils.stringify(session.total) or ''
  if total == '' then
    return labels.get('mcanouil-session') .. ' ' .. number
  end
  return (labels.get('mcanouil-session-of'):gsub('{number}', number):gsub('{total}', total))
end

--- Answer the duration of a session, `extensions.mcanouil.duration`.
--- @param meta table Document metadata
--- @return string|nil Duration, or nil when it is not set
function M.duration(meta)
  return option(meta, 'duration')
end

--- Answer the duration of a session for the title block partials of HTML and
--- Reveal.js, as a `label` and a `value`.
--- @param meta table Document metadata
--- @return table|nil Duration, or nil when it is not set
function M.duration_field(meta)
  local duration = M.duration(meta)
  if duration == nil then
    return nil
  end
  return {
    label = pandoc.MetaInlines(pandoc.Inlines(labels.get('mcanouil-duration'))),
    value = pandoc.MetaInlines(pandoc.Inlines(duration)),
  }
end

--- Answer the number of an exercise: `<session>.<index>`, or `<index>`.
--- @param index integer Position of the exercise in the document
--- @param session string|nil Session number
--- @return string Number
local function exercise_number(index, session)
  return session and (session .. '.' .. index) or tostring(index)
end

--- Answer the label of an exercise: "Exercise 2.1 · 15 min · pairs".
--- @param index integer Position of the exercise in the document
--- @param session string|nil Session number
--- @param duration string|nil Duration attribute
--- @param format string|nil Format attribute, for example `pairs`
--- @return string Label
function M.exercise_label(index, session, duration, format)
  local parts = { labels.get('mcanouil-exercise') .. ' ' .. exercise_number(index, session) }
  parts[#parts + 1] = duration
  parts[#parts + 1] = format
  return table.concat(parts, SEPARATOR)
end

--- Answer the label of a solution: "Solution", with the number of its
--- exercise when it is given, then its `name` attribute when it is set, as in
--- "Solution 2.1 · Worked answer".
--- @param name string|nil Name of the solution
--- @param number string|nil Number of its exercise
--- @return string Label
function M.solution_label(name, number)
  local parts = { labels.get('mcanouil-solution') .. (number and (' ' .. number) or '') }
  parts[#parts + 1] = name
  return table.concat(parts, SEPARATOR)
end

--- Answer how the PDF shows the solutions, `extensions.mcanouil.solutions`.
--- @param meta table Document metadata
--- @return string|nil Mode: `end`, `inline` or `hide`
--- @return string|nil Message, when the option names an unknown mode
function M.solutions_mode(meta)
  local mode = option(meta, 'solutions') or M.MODES[1]
  for _, known in ipairs(M.MODES) do
    if mode == known then
      return mode
    end
  end
  return nil, string.format('mcanouil: unknown solutions "%s"; use %s.', mode, table.concat(M.MODES, ', '))
end

--- Escape text for HTML.
--- @param text string
--- @return string
local function escape_html(text)
  return (text:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;'))
end

--- Answer the kind of a workshop block, from its classes.
--- @param div pandoc.Div
--- @return string|nil Kind, or nil for another division
local function kind_of(div)
  for _, kind in ipairs({ 'objectives', 'prerequisites', 'exercise', 'solution', 'checkpoint' }) do
    if div.classes:includes(kind) then
      return kind
    end
  end
  return nil
end

--- Answer a block as an HTML group named by its visible label.
--- @param div pandoc.Div Workshop block
--- @param kind string Kind of the block
--- @param label string Label text
--- @param state table Workshop state
--- @param content pandoc.Blocks Content of the block
--- @param extra table<string, string>|nil More attributes
--- @return pandoc.Div Block
local function html_group(div, kind, label, state, content, extra)
  state.labels = state.labels + 1
  local label_id = 'mc-ws-label-' .. state.labels
  local blocks = pandoc.Blocks({
    pandoc.RawBlock('html', '<p class="mc-ws-label" id="' .. label_id .. '">' .. escape_html(label) .. '</p>'),
  })
  blocks:extend(content)
  local attr = div.attr:clone()
  attr.attributes.duration = nil
  attr.attributes.format = nil
  for _, class in ipairs({ 'mc-ws', 'mc-ws-' .. kind }) do
    attr.classes:insert(class)
  end
  attr.attributes.role = 'group'
  attr.attributes['aria-labelledby'] = label_id
  for key, value in pairs(extra or {}) do
    attr.attributes[key] = value
  end
  return pandoc.Div(blocks, attr)
end

--- Answer a block as a Typst call: `#mc-ws-block("<kind>", "<label>")[...]`.
--- @param kind string Kind of the block
--- @param label string Label text
--- @param content pandoc.Blocks Content of the block
--- @return pandoc.Blocks Blocks
local function typst_block(kind, label, content)
  local blocks = pandoc.Blocks({
    pandoc.RawBlock('typst', '#mc-ws-block("' .. kind .. '", ' .. labels.typst_string(label) .. ')['),
  })
  blocks:extend(content)
  blocks:insert(pandoc.RawBlock('typst', ']'))
  return blocks
end

--- Answer a solution for the output format.
--- @param div pandoc.Div Solution block
--- @param number string Number of its exercise
--- @param state table Workshop state
--- @return pandoc.Blocks Blocks that take the place of the solution in the exercise
local function solution(div, number, state)
  if div.identifier ~= '' then
    state.by_id[div.identifier] = { id = div.identifier, number = number }
  end
  local name = attribute(div.attributes.name)
  div.attributes.name = nil
  local label = M.solution_label(name)
  if state.format == 'html' then
    local attr = div.attr:clone()
    attr.classes:extend({ 'mc-ws', 'mc-ws-solution' })
    local open = pandoc.write(pandoc.Pandoc({ pandoc.Div({}, attr) }), 'html'):match('^<div(.-)>')
    local blocks = pandoc.Blocks({
      pandoc.RawBlock('html', '<details' .. open .. '>\n<summary>' .. escape_html(label) .. '</summary>'),
    })
    blocks:insert(pandoc.Div(div.content, { class = 'mc-ws-solution-body' }))
    blocks:insert(pandoc.RawBlock('html', '</details>'))
    return blocks
  end
  if state.format == 'revealjs' then
    local group = html_group(div, 'solution', label, state, div.content, { group = M.GROUP })
    group.classes:insert('veil')
    return pandoc.Blocks({ group })
  end
  if state.mode == 'inline' then
    local blocks = typst_block('solution', label, div.content)
    if div.identifier ~= '' then
      blocks[#blocks] = pandoc.RawBlock('typst', '] <' .. div.identifier .. '>')
    end
    return blocks
  end
  if state.mode == 'hide' then
    return pandoc.Blocks({})
  end
  local target = '<' .. (div.identifier ~= '' and div.identifier or ('mc-ws-solution-' .. number:gsub('%.', '-'))) .. '>'
  state.solutions[#state.solutions + 1] = { target = target, number = number, name = name, content = div.content }
  return pandoc.Blocks({ pandoc.RawBlock('typst', '#mc-ws-solution-link(' .. target .. ')') })
end

--- Answer an exercise for the output format, with its solutions.
--- @param div pandoc.Div Exercise block
--- @param state table Workshop state
--- @return pandoc.Blocks Blocks
local function exercise(div, state)
  state.exercises = state.exercises + 1
  local number = exercise_number(state.exercises, state.session)
  local label = M.exercise_label(
    state.exercises, state.session, attribute(div.attributes.duration), attribute(div.attributes.format)
  )
  local content = pandoc.Blocks(div.content):walk({
    traverse = 'topdown',
    Div = function(inner)
      if kind_of(inner) == 'solution' then
        return solution(inner, number, state), false
      end
    end,
  })
  if state.format == 'typst' then
    return typst_block('exercise', label, content)
  end
  return pandoc.Blocks({ html_group(div, 'exercise', label, state, content) })
end

--- Answer the solutions collected at the end of a Typst handout: a heading,
--- then one heading and the content of each solution.
--- @param state table Workshop state
--- @return pandoc.Blocks Blocks
local function solutions_at_end(state)
  local blocks = pandoc.Blocks({})
  if #state.solutions == 0 then
    return blocks
  end
  blocks:insert(pandoc.RawBlock('typst', '#mc-ws-solutions-heading(' .. labels.typst_string(labels.get('mcanouil-solutions')) .. ')'))
  for _, entry in ipairs(state.solutions) do
    local title = M.solution_label(entry.name, entry.number)
    blocks:insert(pandoc.RawBlock('typst', '#mc-ws-solution-heading(' .. labels.typst_string(title) .. ') ' .. entry.target))
    blocks:extend(entry.content)
  end
  return blocks
end

--- Declare the veil group of the solutions, hidden by default, unless the
--- author declares it.
--- @param meta table Document metadata
local function declare_group(meta)
  if type(meta.extensions) ~= 'table' then
    meta.extensions = pandoc.MetaMap({})
  end
  local veil = meta.extensions.veil
  if type(veil) ~= 'table' then
    veil = pandoc.MetaMap({})
    meta.extensions.veil = veil
  end
  local groups = veil.groups or pandoc.MetaList({})
  for _, group in ipairs(groups) do
    if group.name ~= nil and pandoc.utils.stringify(group.name) == M.GROUP then
      return
    end
  end
  groups:insert(pandoc.MetaMap({
    name = pandoc.MetaString(M.GROUP),
    shown = false,
    label = pandoc.MetaString(labels.get('mcanouil-solutions')),
  }))
  veil.groups = groups
end

--- @type boolean True when the document is a workshop, set by the detect step.
local is_workshop = false

--- Answer the output format of the workshop blocks.
--- @return string|nil `typst`, `revealjs` or `html`, or nil for another format
local function output_format()
  return quarto.doc.is_format('typst') and 'typst'
    or quarto.doc.is_format('revealjs') and 'revealjs'
    or quarto.doc.is_format('html') and 'html'
    or nil
end

--- Answer whether a document is a workshop in the output format.
--- @param meta table Document metadata
--- @return boolean
local function workshop_type(meta)
  local format = output_format()
  local resolved = format and document.resolve(meta, 'mcanouil-' .. format)
  return resolved ~= nil and resolved.type == 'workshop'
end

--- Note whether the document is a workshop, for the solution step.
--- @param meta table Document metadata
local function detect(meta)
  is_workshop = workshop_type(meta)
end

--- Answer a solution of a workshop as a division, from the `Proof` node that
--- Quarto makes of a `.solution` block or a `sol-` identifier. The node is
--- replaced as a whole; its `div` slot is read, never changed. The division
--- gets the identifier, the classes (with `solution` first), the attributes
--- and the content of the block, and the name of the proof as its `name`
--- attribute. Quarto takes the name from the `name` attribute, else from a
--- leading heading, which it removes; either way it joins the solution label.
--- Other documents keep the proof.
--- @param proof table Quarto `Proof` node
--- @return pandoc.Div|nil Division, or nil to keep the node
local function from_proof(proof)
  if not is_workshop or pandoc.utils.stringify(proof.type or ''):lower() ~= 'solution' then
    return nil
  end
  local attr = proof.div.attr:clone()
  attr.identifier = proof.identifier or ''
  attr.classes:insert(1, 'solution')
  local name = proof.name ~= nil and pandoc.utils.stringify(proof.name) or ''
  if name ~= '' then
    attr.attributes.name = name
  end
  return pandoc.Div(proof.div.content, attr)
end

--- Answer the inlines of a reference to a workshop solution: a link to it,
--- with the label "Solution 2.1". In a PDF handout without solutions, the
--- label alone.
--- @param entry table Solution: `id`, `number`
--- @param state table Workshop state
--- @return pandoc.Inlines Inlines
local function solution_reference(entry, state)
  local text = M.solution_label(nil, entry.number)
  if state.format == 'typst' then
    if state.mode == 'hide' then
      return pandoc.Inlines(text)
    end
    return pandoc.Inlines({ pandoc.RawInline('typst', '#link(<' .. entry.id .. '>)[' .. text .. ']') })
  end
  return pandoc.Inlines({ pandoc.Link(pandoc.Inlines(text), '#' .. entry.id, '', { class = 'quarto-xref' }) })
end

--- Replace each reference to a workshop solution, such as `@sol-a`, with a link
--- to the solution. Quarto's cross-references do not index a workshop solution
--- (it is not a proof there), so the workshop step resolves them, with the
--- numbers of its own labels. A citation that holds anything else is kept.
--- @param blocks pandoc.Blocks
--- @param state table Workshop state
--- @return pandoc.Blocks Blocks
local function resolve_references(blocks, state)
  return blocks:walk({
    Cite = function(cite)
      if #cite.citations ~= 1 or state.by_id[cite.citations[1].id] == nil then
        return nil
      end
      local citation = cite.citations[1]
      local inlines = pandoc.Inlines({})
      if #citation.prefix > 0 then
        inlines:extend(citation.prefix)
        inlines:insert(pandoc.Space())
      end
      inlines:extend(solution_reference(state.by_id[citation.id], state))
      inlines:extend(citation.suffix)
      return inlines
    end,
  })
end

--- Rewrite the workshop blocks of a document.
--- @param doc pandoc.Pandoc Document
--- @return pandoc.Pandoc Document
local function arrange(doc)
  if not workshop_type(doc.meta) then
    return doc
  end
  local format = output_format()
  local mode, message = M.solutions_mode(doc.meta)
  if not mode then
    fail.raise(message)
  end
  local state = {
    format = format,
    mode = mode,
    session = document.session_number(doc.meta),
    exercises = 0,
    labels = 0,
    solutions = {},
    by_id = {},
  }
  doc.blocks = doc.blocks:walk({
    traverse = 'topdown',
    Div = function(div)
      local kind = kind_of(div)
      if kind == nil then
        return nil
      end
      if kind == 'solution' then
        fail.raise('mcanouil: a .solution block must sit inside an .exercise block; move it into the exercise it solves.')
      end
      if kind == 'exercise' then
        return exercise(div, state), false
      end
      local label = labels.get(M.LABELS[kind])
      if format == 'typst' then
        return typst_block(kind, label, div.content), false
      end
      return html_group(div, kind, label, state, div.content), false
    end,
  })
  doc.blocks = resolve_references(doc.blocks, state)
  if format == 'typst' then
    doc.blocks:extend(solutions_at_end(state))
    doc.meta['mcanouil-session'] = M.session_text(doc.meta)
    doc.meta['mcanouil-duration'] = M.duration(doc.meta)
  end
  if format == 'revealjs' then
    declare_group(doc.meta)
  end
  return doc
end

--- @type table[] Filter steps of the entry filter, in order: note the type,
--- turn Quarto's solution proofs into divisions, then rewrite the blocks.
M.filters = {
  { Meta = fail.guard(detect) },
  { Proof = fail.guard(from_proof) },
  { Pandoc = fail.guard(arrange) },
}

return M
