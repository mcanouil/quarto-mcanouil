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
--- and its `format`; a solution label holds its `name`. A solution keeps its
--- content, identifier, classes and other attributes. A solution is a native `<details>` disclosure in HTML, a
--- block of the veil group `solutions`, hidden until shown, in Reveal.js, and
--- in Typst, after `extensions.mcanouil.solutions`: collected at the end behind
--- a "Solution: page n" link (`end`, the default), in its exercise (`inline`),
--- or left out (`hide`).

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
    return typst_block('solution', label, div.content)
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

--- @type string Class that keeps a solution of a workshop away from Quarto,
--- which reads `.solution` as its own proof environment and takes its leading
--- heading and `name` attribute apart. The step before Quarto's parse sets it,
--- and the workshop step sets `.solution` back.
M.SOURCE_CLASS = 'mc-ws-solution-source'

--- @type string Prefix of a solution identifier that Quarto reads as a proof
--- cross-reference, and the private prefix that hides it until the workshop step.
M.SOLUTION_ID_PREFIX = 'sol-'
M.SOURCE_ID_PREFIX = 'mc-ws-sol-'

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

--- Swap one class of a division for another, in place, keeping its position.
--- @param div pandoc.Div
--- @param from string Class to replace
--- @param to string New class
--- @return pandoc.Div|nil The division, or nil when it lacks the class
local function swap_class(div, from, to)
  for index, class in ipairs(div.classes) do
    if class == from then
      div.classes[index] = to
      return div
    end
  end
  return nil
end

--- Hide a solution of a workshop from Quarto's proof parse, which reads both
--- the class `solution` and an identifier that starts with `sol-`: the class
--- becomes `mc-ws-solution-source` and the prefix `mc-ws-sol-`, with no other
--- change to its content, identifier, classes or attributes. Other documents keep the
--- proof environment.
--- @param div pandoc.Div
--- @return pandoc.Div|nil
local function hide_solution(div)
  if not is_workshop then
    return nil
  end
  local hidden = swap_class(div, 'solution', M.SOURCE_CLASS)
  if div.identifier:sub(1, #M.SOLUTION_ID_PREFIX) == M.SOLUTION_ID_PREFIX then
    div.identifier = M.SOURCE_ID_PREFIX .. div.identifier:sub(#M.SOLUTION_ID_PREFIX + 1)
    hidden = div
  end
  return hidden
end

--- Set back the class and the identifier that `hide_solution` changed.
--- @param div pandoc.Div
--- @return pandoc.Div|nil
local function restore_solution(div)
  local restored = swap_class(div, M.SOURCE_CLASS, 'solution')
  if div.identifier:sub(1, #M.SOURCE_ID_PREFIX) == M.SOURCE_ID_PREFIX then
    div.identifier = M.SOLUTION_ID_PREFIX .. div.identifier:sub(#M.SOURCE_ID_PREFIX + 1)
    restored = div
  end
  return restored
end

--- Rewrite the workshop blocks of a document.
--- @param doc pandoc.Pandoc Document
--- @return pandoc.Pandoc Document
local function arrange(doc)
  if not workshop_type(doc.meta) then
    return doc
  end
  local format = output_format()
  doc.blocks = doc.blocks:walk({
    Div = restore_solution,
  })
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

--- @type table[] Filter steps that run before Quarto parses the document: note
--- the type, then hide the solutions from the proof parse.
M.pre_filters = {
  { Meta = fail.guard(detect) },
  { Div = fail.guard(hide_solution) },
}

--- @type table Filter step of the entry filter.
M.filter = { Pandoc = fail.guard(arrange) }

return M
