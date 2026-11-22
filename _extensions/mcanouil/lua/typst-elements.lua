--- @module "typst-elements"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Structured elements in Typst: callouts, code, task lists, keys, details and maths
--- @description Writes the Typst calls that typst/lib/elements.typ styles from
--- the preset tokens.
---
--- Before Quarto's filters, each callout gets a marker as the first block of its
--- body: `#metadata((mc-callout: "<type>", appearance: "<appearance>", titled: <bool>))`.
--- Quarto's Typst callout call carries no type, so the `callout` function of
--- the template reads the marker and drops it from the body.
---
--- After Quarto's filters and the embedded tools:
--- - inline code goes in `#mc-inline-code[...]`, in place of the box of the
---   embedded code-window, whose fill comes from the highlighting theme;
--- - the code blocks of a code window take the tint of the preset;
--- - a task list goes in `#mc-task-list[...]`, and its `☐` and `☒` marks become
---   `#mc-task(false)` and `#mc-task(true)`, which draw the box with an
---   alternative text that gives the state, because the fonts of the presets
---   have no ballot box glyphs and PDF/UA-1 needs each glyph;
--- - a `<kbd>` pair becomes `#mc-kbd[...]`, and a `<details>` with its
---   `<summary>` becomes `#mc-details([...], [...])`, which Pandoc drops otherwise;
--- - maths with no alternative text gets its TeX source as the alternative
---   text, which PDF/UA-1 needs. Maths that typst-extras or Quarto already
---   wrap in `#math.equation(` keeps its call; a Quarto equation call without
---   `alt:` gets the TeX source.

local fail = require('lib.fail')
local labels = require('lib.labels')

local M = {}

--- @type table<string, boolean> Ballot box marks that Pandoc writes for a task, and their state.
M.TASK_MARKS = { ['\u{2610}'] = false, ['\u{2612}'] = true }

--- @type string Typst text that closes an equation call opened by typst-extras or by this module.
local CLOSE_EQUATION = '.body)'

--- Answer the alternative text of maths: its TeX source on one line.
--- @param tex string TeX source
--- @return string Alternative text
function M.math_alt(tex)
  return (tex:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', ''))
end

--- Answer the marker that the Typst `callout` function reads.
--- @param kind string Callout type, for example `note`
--- @param appearance string|nil Callout appearance: `default`, `simple` or `minimal`
--- @param titled boolean True when the callout has its own title
--- @return string Typst code
function M.callout_marker(kind, appearance, titled)
  return string.format(
    '#metadata((mc-callout: %s, appearance: %s, titled: %s))',
    labels.typst_string(kind),
    labels.typst_string(appearance or 'default'),
    tostring(titled)
  )
end

--- Put the marker of a callout in front of its body.
--- @param callout table Quarto callout node
--- @return table|nil Callout
local function mark_callout(callout)
  if not quarto.doc.is_format('typst') then
    return nil
  end
  local titled = callout.title ~= nil and not quarto.utils.is_empty_node(callout.title)
  local marker = M.callout_marker(callout.type or 'note', callout.appearance, titled)
  local content = pandoc.Blocks({ pandoc.RawBlock('typst', marker) })
  if callout.content ~= nil then
    content:extend(quarto.utils.as_blocks(callout.content))
  end
  callout.content = content
  return callout
end

--- Answer whether an inline is raw Typst that opens an equation call, which
--- the next inline, the maths, completes.
--- @param inline pandoc.Inline|nil
--- @return boolean
local function opens_equation(inline)
  if inline == nil or inline.t ~= 'RawInline' or inline.format ~= 'typst' then
    return false
  end
  local text = inline.text
  return text:find('#math.equation(', 1, true) ~= nil and (text:sub(-2) == ', ' or text:sub(-2) == '[ ')
end

--- Answer whether an inline is the raw Typst box that the embedded code-window
--- puts around inline code, and the text that closes it.
--- @param inline pandoc.Inline|nil
--- @return string|nil Closing text, or nil when the inline is no such box
local function code_box_closing(inline)
  if inline == nil or inline.t ~= 'RawInline' or inline.format ~= 'typst' then
    return nil
  end
  if inline.text:match('^#box%(fill: .*%)%[$') then
    return ']'
  end
  if inline.text:match('^#context { .*box%(fill: .*%)%[$') then
    return '] }'
  end
  return nil
end

--- Add inline code to a list of inlines, in the inline code box of the preset.
--- @param result pandoc.Inlines
--- @param code pandoc.Code
local function insert_code(result, code)
  result:insert(pandoc.RawInline('typst', '#mc-inline-code['))
  result:insert(code)
  result:insert(pandoc.RawInline('typst', ']'))
end

--- Answer whether an inline is one that rewrite_inlines changes.
--- @param inline pandoc.Inline
--- @return boolean
local function rewritable(inline)
  return inline.t == 'Code'
    or inline.t == 'Math'
    or (inline.t == 'RawInline' and (inline.format == 'html' or code_box_closing(inline) ~= nil))
end

--- Rewrite the maths and the inline code of a list of inlines.
--- @param inlines pandoc.Inlines
--- @return pandoc.Inlines|nil
local function rewrite_inlines(inlines)
  if not inlines:find_if(rewritable) then
    return nil
  end
  local result = pandoc.Inlines({})
  local changed = false
  local index = 1
  while index <= #inlines do
    local inline = inlines[index]
    local closing = code_box_closing(inline)
    local code = inlines[index + 1]
    local after = inlines[index + 2]
    if
      closing
      and code ~= nil
      and code.t == 'Code'
      and after ~= nil
      and after.t == 'RawInline'
      and after.text == closing
    then
      insert_code(result, code)
      changed = true
      index = index + 3
    elseif inline.t == 'Code' then
      insert_code(result, inline)
      changed = true
      index = index + 1
    elseif inline.t == 'Math' then
      local previous = result[#result]
      if opens_equation(previous) then
        if not previous.text:find('alt:', 1, true) then
          local alt = labels.typst_string(M.math_alt(inline.text))
          local text, count = previous.text:gsub('#math%.equation%(', function(call)
            return call .. 'alt: ' .. alt .. ', '
          end, 1)
          if count == 0 then
            fail.raise('mcanouil: cannot add the alternative text of the equation ' .. inline.text .. ' to ' .. previous.text .. '.')
          end
          previous.text = text
        end
        result:insert(inline)
      else
        local alt = labels.typst_string(M.math_alt(inline.text))
        local block = inline.mathtype == 'DisplayMath' and 'true' or 'false'
        result:insert(pandoc.RawInline('typst', '#math.equation(block: ' .. block .. ', alt: ' .. alt .. ', '))
        result:insert(inline)
        result:insert(pandoc.RawInline('typst', CLOSE_EQUATION))
      end
      changed = true
      index = index + 1
    elseif inline.t == 'RawInline' and inline.format == 'html' and inline.text:match('^<kbd>$') then
      result:insert(pandoc.RawInline('typst', '#mc-kbd['))
      changed = true
      index = index + 1
    elseif inline.t == 'RawInline' and inline.format == 'html' and inline.text:match('^</kbd>$') then
      result:insert(pandoc.RawInline('typst', ']'))
      changed = true
      index = index + 1
    else
      result:insert(inline)
      index = index + 1
    end
  end
  return changed and result or nil
end

--- Answer the state of a list item that starts with a task mark.
--- @param item pandoc.Blocks Item of a bullet list
--- @return boolean|nil State, or nil when the item is no task
local function task_state(item)
  local first = item[1]
  if first == nil or (first.t ~= 'Plain' and first.t ~= 'Para') then
    return nil
  end
  local mark = first.content[1]
  if mark == nil or mark.t ~= 'Str' then
    return nil
  end
  return M.TASK_MARKS[mark.text]
end

--- Rewrite a task list: each mark becomes a drawn box, and the list goes in
--- the task list call. A list whose first item is no task stays as it is.
--- @param list pandoc.BulletList
--- @return pandoc.Blocks|nil
local function rewrite_task_list(list)
  if task_state(list.content[1] or {}) == nil then
    return nil
  end
  for _, item in ipairs(list.content) do
    local done = task_state(item)
    if done ~= nil then
      local inlines = item[1].content
      inlines[1] = pandoc.RawInline('typst', '#mc-task(' .. tostring(done) .. ')')
      if inlines[2] ~= nil and inlines[2].t == 'Space' then
        inlines[2] = pandoc.RawInline('typst', ' ')
      end
    end
  end
  return pandoc.Blocks({
    pandoc.RawBlock('typst', '#mc-task-list['),
    list,
    pandoc.RawBlock('typst', ']'),
  })
end

--- @type table<string, string> Typst text for each HTML tag of a details element.
local DETAILS_TAGS = {
  ['<summary>'] = '[',
  ['</summary>'] = '], [',
  ['</details>'] = '])',
}

--- Answer the HTML tag of a raw block of a details element.
--- @param block pandoc.Block
--- @return string|nil Tag: `<details>`, `<summary>`, `</summary>` or `</details>`
local function details_tag(block)
  if block.t ~= 'RawBlock' or block.format ~= 'html' then
    return nil
  end
  local text = block.text:gsub('^%s+', ''):gsub('%s+$', '')
  if text:match('^<details[%s>]') or text == '<details>' then
    return '<details>'
  end
  if DETAILS_TAGS[text] then
    return text
  end
  return nil
end

--- Rewrite the details elements of a list of blocks. Each must read
--- `<details>`, `<summary>`, summary, `</summary>`, content, `</details>`,
--- and may hold other details elements in its content; otherwise the list
--- stays as it is.
--- @param blocks pandoc.Blocks
--- @return pandoc.Blocks|nil
local function rewrite_details(blocks)
  local expected = {}
  local found = false
  for index, block in ipairs(blocks) do
    local tag = details_tag(block)
    if tag == '<details>' then
      local next_tag = blocks[index + 1] and details_tag(blocks[index + 1])
      if next_tag ~= '<summary>' then
        return nil
      end
      table.insert(expected, '<summary>')
      found = true
    elseif tag ~= nil then
      if expected[#expected] ~= tag then
        return nil
      end
      table.remove(expected)
      if tag == '<summary>' then
        table.insert(expected, '</summary>')
      elseif tag == '</summary>' then
        table.insert(expected, '</details>')
      end
    end
  end
  if not found or #expected > 0 then
    return nil
  end
  local result = pandoc.Blocks({})
  for _, block in ipairs(blocks) do
    local tag = details_tag(block)
    if tag == '<details>' then
      result:insert(pandoc.RawBlock('typst', '#mc-details('))
    elseif tag ~= nil then
      result:insert(pandoc.RawBlock('typst', DETAILS_TAGS[tag]))
    else
      result:insert(block)
    end
  end
  return result
end

--- @type string Comment that marks the Skylighting override of the embedded code-window.
local SKYLIGHTING_OVERRIDE = '// skylighting-typst-fix override'

--- @type string Typst code that gives the code blocks the tint of the preset
--- when the caller sets no fill. It follows the last definition of Skylighting.
M.SKYLIGHTING_TINT = table.concat({
  '#let mc-skylighting = Skylighting',
  '#let Skylighting(fill: none, ..args) = mc-skylighting(fill: if fill == none { mc-tokens.tint } else { fill }, ..args)',
}, '\n')

--- Give the code blocks the tint of the preset, after the Skylighting
--- override of the embedded code-window. Without the override, Skylighting
--- may be undefined (no highlighting) or ignore its fill, so the document is
--- left as it is.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc
local function tint_code(doc)
  for index, block in ipairs(doc.blocks) do
    if block.t == 'RawBlock' and block.format == 'typst' and block.text:find(SKYLIGHTING_OVERRIDE, 1, true) then
      doc.blocks:insert(index + 1, pandoc.RawBlock('typst', M.SKYLIGHTING_TINT))
      break
    end
  end
  return doc
end

--- Rewrite the structured elements of a Typst document.
--- @param doc pandoc.Pandoc
--- @return pandoc.Pandoc|nil
local function rewrite(doc)
  if not quarto.doc.is_format('typst') then
    return nil
  end
  doc = doc:walk({
    Inlines = rewrite_inlines,
    BulletList = rewrite_task_list,
    Blocks = rewrite_details,
  })
  return tint_code(doc)
end

--- @type table Filter step that marks callouts, before Quarto's filters.
M.pre_filter = { Callout = fail.guard(mark_callout) }

--- @type table Filter step that rewrites the elements, after the embedded tools.
M.post_filter = { Pandoc = fail.guard(rewrite) }

return M
