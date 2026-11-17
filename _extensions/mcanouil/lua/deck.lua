--- @module "deck"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Slide types of a Reveal.js deck
--- @description Puts the title, section and closing slides on the dark ground
--- of the preset with its corner motif, gives a slide with the `dark` class the
--- dark paper, numbers the section slides, fills the three footer slots, builds
--- the closing slide from `extensions.mcanouil.closing`, delivers to the
--- title slide partial the event, the speakers and the motif, and adds the
--- style layer of the preset after the theme, so that it wins over the theme.

local fail = require('lib.fail')
local labels = require('lib.labels')
local motif = require('lib.motif')
local preset = require('preset')
local document = require('document')
local authors = require('authors')

--- @type string Directory of the extension, the parent of `lua/`.
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\][^/\\]+$')

local M = {}

--- @type string Class of a slide that the author sets to the dark scheme.
M.DARK_CLASS = 'dark'

--- @type string Class that tells Reveal.js and Quarto that a slide has a dark background, so the footer and the slide number follow.
M.DARK_BACKGROUND_CLASS = 'has-dark-background'

--- @type string Value of `data-state` on the slides with no footer, no slide number and no menu button.
M.BARE_STATE = 'mc-bare'

--- @type string Value of `data-state` on the slides with a dark background, so the menu button follows.
M.DARK_STATE = 'mc-dark'

--- @type string Warning when the footer has no slide number in its right slot.
M.SLIDE_NUMBER_WARNING = 'mcanouil: the deck footer has no "page" in its right slot, so the slide number is off; '
  .. 'set extensions.mcanouil.footer.right to page to show it.'

--- @type string Warning for a speaker photo without alt text.
M.PHOTO_ALT_WARNING = 'mcanouil: the speaker photo "%s" has no alt text; add alt next to photo in extensions.mcanouil.speakers.'

--- @type string Identifier of the closing slide.
M.CLOSING_ID = 'mc-closing'

--- @type integer Length of a title, in characters, above which the title slide sets it smaller.
M.LONG_TITLE = 48

--- @type integer Length of a section title, in characters, above which the section slide sets it smaller.
M.LONG_SECTION = 32

--- @type string Class of a section slide with a long title.
M.LONG_CLASS = 'mc-long'

--- @type table<string, integer> Digits of a section number, for the presets that pad it.
M.NUMBER_DIGITS = { terminal = 2 }

--- @type table<string, string> MIME type of each image file extension of a speaker photo.
local MIME_TYPES = {
  svg = 'image/svg+xml', png = 'image/png', jpg = 'image/jpeg', jpeg = 'image/jpeg', gif = 'image/gif', webp = 'image/webp',
}

--- Read a file.
--- @param path string File
--- @param what string What the file is, for the message
--- @return string Content
local function read_file(path, what)
  local file = io.open(path, 'rb')
  if not file then
    fail.raise(string.format('mcanouil: cannot open the %s %s.', what, path))
  end
  local content = file:read('a')
  file:close()
  return content
end

--- Answer the CSS gradient of the ground.
--- @param tokens table<string, string> Hex colour of each token
--- @return string CSS gradient
function M.ground_gradient(tokens)
  return 'linear-gradient(135deg, ' .. tokens['ground-1'] .. ', ' .. tokens['ground-2'] .. ')'
end

--- Answer the text of a section number.
--- @param number integer Section number
--- @param preset_name string Preset
--- @return string Number, padded for the presets that pad it
function M.section_number(number, preset_name)
  return string.format('%0' .. (M.NUMBER_DIGITS[preset_name] or 1) .. 'd', number)
end

--- Answer an option of `extensions.mcanouil`.
--- @param meta table Document metadata
--- @param key string Option name
--- @return any|nil Value
local function option(meta, key)
  local options = meta.extensions and meta.extensions.mcanouil
  return options and options[key]
end

--- Answer the photo of a speaker as a data URI, so that the deck carries it.
--- @param path string Photo file, relative to the document
--- @return string Data URI
local function photo_uri(path)
  local extension = (path:match('%.([^./\\]+)$') or ''):lower()
  local mime = MIME_TYPES[extension]
  if mime == nil then
    fail.raise(string.format('mcanouil: the speaker photo "%s" must be an svg, png, jpg, gif or webp file.', path))
  end
  local full = path
  if path:sub(1, 1) ~= '/' and quarto.doc.input_file then
    full = pandoc.path.join({ pandoc.path.directory(quarto.doc.input_file), path })
  end
  return 'data:' .. mime .. ';base64,' .. quarto.base64.encode(read_file(full, 'speaker photo'))
end

--- Answer the speakers of the title slide: name, degrees, first affiliation,
--- and the photo and its alt text from `extensions.mcanouil.speakers`, matched
--- to the authors by order. A photo without alt text warns.
--- @param meta table Document metadata
--- @return table List of speaker maps
local function speakers(meta)
  local collected = authors.collect(meta)
  if collected == nil then
    return {}
  end
  local extras = option(meta, 'speakers') or {}
  local list = {}
  for index, record in ipairs(collected.authors) do
    local extra = extras[index] or {}
    local speaker = { name = pandoc.MetaString(record.name) }
    if #record.degrees > 0 then
      speaker.degrees = pandoc.MetaString(table.concat(record.degrees, ', '))
    end
    if record.affiliations[1] ~= nil and collected.affiliations[record.affiliations[1]] ~= nil then
      speaker.affiliation = pandoc.MetaString(collected.affiliations[record.affiliations[1]])
    end
    if extra.photo ~= nil then
      local path = pandoc.utils.stringify(extra.photo)
      local alt = extra.alt and pandoc.utils.stringify(extra.alt) or ''
      if alt == '' then
        quarto.log.warning(string.format(M.PHOTO_ALT_WARNING, path))
      end
      speaker.photo = pandoc.MetaString(photo_uri(path))
      speaker['photo-alt'] = pandoc.MetaString(alt)
    end
    list[#list + 1] = speaker
  end
  return list
end

--- Answer the attributes of a slide on the ground.
--- @param state table Deck state
--- @param bare boolean True for a slide with no footer and no slide number
--- @return table<string, string> Attributes
local function ground_attributes(state, bare)
  local attributes = { ['background-gradient'] = M.ground_gradient(state.dark), ['data-state'] = M.DARK_STATE }
  if bare then
    attributes['data-footer'] = 'false'
    attributes['data-state'] = M.BARE_STATE .. ' ' .. M.DARK_STATE
  end
  return attributes
end

--- Add states to the `data-state` of a slide, after the states the author set.
--- @param attr pandoc.Attr Attribute set of the slide heading
--- @param states string States, separated by spaces
local function add_state(attr, states)
  local list, seen = {}, {}
  for state in ((attr.attributes['data-state'] or '') .. ' ' .. states):gmatch('%S+') do
    if not seen[state] then
      seen[state] = true
      list[#list + 1] = state
    end
  end
  attr.attributes['data-state'] = table.concat(list, ' ')
end

--- Add classes and attributes to an attribute set.
--- @param attr pandoc.Attr Attribute set
--- @param classes string[] Classes
--- @param attributes table<string, string> Attributes
local function extend_attr(attr, classes, attributes)
  for _, class in ipairs(classes) do
    if not attr.classes:includes(class) then
      attr.classes:insert(class)
    end
  end
  for key, value in pairs(attributes) do
    if key == 'data-state' then
      add_state(attr, value)
    else
      attr.attributes[key] = value
    end
  end
end

--- Answer the motif block of a slide.
--- @param state table Deck state
--- @return pandoc.RawBlock Motif
local function motif_block(state)
  state.motifs = state.motifs + 1
  return pandoc.RawBlock('html', motif.svg(state.motif, tostring(state.motifs)))
end

--- Answer whether the right footer slot of a deck holds the slide number.
--- Reveal.js draws the slide number in one place only, over the right slot.
--- @param furniture table Furniture from `document.furniture`
--- @return boolean
function M.page_on_right(furniture)
  local right = furniture.footer.right
  return right.kind == 'field' and right.value == 'page'
end

--- Answer the content of the three footer slots, as spans. `page` gives an
--- empty slot; in the right slot, the slide number of Reveal.js sits over it.
--- @param meta table Document metadata
--- @param furniture table Furniture from `document.furniture`
--- @return pandoc.Inlines Footer content
local function footer_slots(meta, furniture)
  local inlines = pandoc.Inlines({})
  for _, slot in ipairs(document.SLOTS) do
    local value = furniture.footer[slot]
    local classes = { 'mc-slot', 'mc-slot-' .. slot }
    local content
    if value.kind == 'field' and value.value == 'page' then
      if slot == 'right' then
        classes[#classes + 1] = 'mc-slot-page'
      end
      content = pandoc.Inlines({})
    elseif value.kind == 'field' and value.value == 'chapter' then
      content = pandoc.Inlines({})
    else
      content = document.resolve_slot(value, meta)
    end
    inlines:insert(pandoc.Span(content, { class = table.concat(classes, ' ') }))
  end
  return inlines
end

--- Answer the closing slide, from `extensions.mcanouil.closing`.
--- @param closing any Closing options: `title`, `links` and `licence`, or `true`
--- @param state table Deck state
--- @return pandoc.Blocks Closing slide
local function closing_slide(closing, state)
  local settings = pandoc.utils.type(closing) == 'table' and closing or {}
  local title = settings.title and pandoc.Inlines(settings.title) or pandoc.Inlines(labels.get('mcanouil-closing-thanks'))
  local header = pandoc.Header(2, title, { id = M.CLOSING_ID })
  extend_attr(header.attr, { preset.GROUND_CLASS, 'mc-closing', M.DARK_BACKGROUND_CLASS }, ground_attributes(state, true))
  local blocks = pandoc.Blocks({ header, motif_block(state) })
  local items = {}
  for _, link in ipairs(settings.links or {}) do
    items[#items + 1] = { pandoc.Plain(pandoc.Inlines(pandoc.utils.stringify(link))) }
  end
  if #items > 0 then
    blocks:insert(pandoc.Div({ pandoc.BulletList(items) }, { class = 'mc-closing-links' }))
  end
  if settings.licence ~= nil then
    blocks:insert(pandoc.Div({ pandoc.Para(pandoc.Inlines(pandoc.utils.stringify(settings.licence))) }, { class = 'mc-closing-licence' }))
  end
  return blocks
end

--- Put a section slide on the ground, with its motif and its number.
--- @param header pandoc.Header Level 1 heading
--- @param state table Deck state
--- @return pandoc.Block[] Heading, motif and number
local function section_slide(header, state)
  extend_attr(header.attr, { preset.GROUND_CLASS, 'mc-section', M.DARK_BACKGROUND_CLASS }, ground_attributes(state, false))
  if utf8.len(pandoc.utils.stringify(header.content)) > M.LONG_SECTION then
    extend_attr(header.attr, { M.LONG_CLASS }, {})
  end
  local blocks = { header, motif_block(state) }
  if not header.classes:includes('unnumbered') then
    state.sections = state.sections + 1
    blocks[#blocks + 1] = pandoc.RawBlock(
      'html', '<p class="mc-section-number">' .. M.section_number(state.sections, state.preset) .. '</p>'
    )
  end
  return blocks
end

--- Fill the footer of the deck that Quarto adds, unless the author set a footer.
--- @param div pandoc.Div The `footer-default` division
--- @param meta table Document metadata
--- @param furniture table Furniture from `document.furniture`
local function fill_footer(div, meta, furniture)
  if pandoc.utils.stringify(div.content) ~= '' then
    return
  end
  div.content = { pandoc.Plain(footer_slots(meta, furniture)) }
  div.classes:insert('mc-footer')
end

--- Walk the top-level blocks and the Quarto furniture, and add the slide types.
--- @param doc pandoc.Pandoc Document
--- @return pandoc.Pandoc Document
local function arrange(doc)
  if not quarto.doc.is_format('revealjs') then
    return doc
  end
  local resolved = preset.resolve(doc.meta)
  local state = {
    preset = resolved.name,
    motif = preset.read(resolved.name).motif,
    dark = preset.tokens(doc.meta).dark,
    motifs = 0,
    sections = 0,
  }
  local furniture = document.furniture(doc.meta, 'deck')
  local slide_number = doc.meta.slideNumber
  local number_off = slide_number == false or (slide_number ~= nil and pandoc.utils.stringify(slide_number) == 'false')
  if not M.page_on_right(furniture) and not number_off then
    quarto.log.warning(M.SLIDE_NUMBER_WARNING)
    doc.meta.slideNumber = false
  end
  local has_refs, has_cites = false, false
  doc:walk({
    Div = function(div) has_refs = has_refs or div.identifier == 'refs' end,
    Cite = function() has_cites = true end,
  })
  local blocks = pandoc.Blocks({})
  for _, block in ipairs(doc.blocks) do
    if block.t == 'Header' and block.level == 1 then
      blocks:extend(section_slide(block, state))
    elseif block.t == 'Header' and block.classes:includes(M.DARK_CLASS) then
      extend_attr(block.attr, { M.DARK_BACKGROUND_CLASS }, {
        ['background-color'] = state.dark.paper,
        ['data-state'] = M.DARK_STATE,
      })
      blocks:insert(block)
    elseif block.t == 'Div' and block.classes:includes('quarto-auto-generated-content') then
      block = block:walk({
        Div = function(div)
          if div.classes:includes('footer-default') then
            fill_footer(div, doc.meta, furniture)
            return div
          end
        end,
      })
      blocks:insert(block)
    else
      blocks:insert(block)
    end
  end
  local closing = option(doc.meta, 'closing')
  if closing ~= nil and closing ~= false then
    if has_cites and not has_refs then
      blocks:insert(pandoc.Div({}, { id = 'refs' }))
    end
    blocks:extend(closing_slide(closing, state))
  end
  doc.blocks = blocks

  local meta = doc.meta
  meta['mcanouil-motif-svg'] = pandoc.MetaBlocks({
    pandoc.RawBlock('html', motif.svg(state.motif, 'title')),
  })
  local event = option(meta, 'event')
  if event ~= nil then
    meta['mcanouil-event'] = event
  end
  meta['mcanouil-speakers'] = speakers(meta)
  if meta.title ~= nil and utf8.len(pandoc.utils.stringify(meta.title)) > M.LONG_TITLE then
    meta['mcanouil-title-long'] = true
  end
  local attributes = meta['title-slide-attributes'] or {}
  attributes['data-background-gradient'] = M.ground_gradient(state.dark)
  attributes['data-footer'] = 'false'
  attributes['data-state'] = M.BARE_STATE .. ' ' .. M.DARK_STATE
  meta['title-slide-attributes'] = attributes
  quarto.doc.include_text('in-header', table.concat({
    '<style id="mcanouil-deck-preset">',
    read_file(EXTENSION_DIR .. '/revealjs/presets/' .. state.preset .. '.css', 'preset style file'),
    '</style>',
  }, '\n'))
  return doc
end

--- @type table Filter step of the entry filter.
M.filter = { Pandoc = fail.guard(arrange) }

return M
