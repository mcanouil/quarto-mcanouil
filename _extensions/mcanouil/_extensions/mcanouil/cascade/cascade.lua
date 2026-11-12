--- Reveal.js Cascade - Filter
--- @module "cascade"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @description Repeat top-level headings on slides created with horizontal
---   rules (`---`).
---   In reveal.js presentations, a `---` separator creates a new slide without
---   a heading.
---   This filter replaces each `HorizontalRule` with clones of the heading
---   chain from the most recent slide.
---
---   When `---` is followed by a heading, only parent headings above that
---   level are repeated.
---   When followed by non-heading content, the entire heading chain is
---   repeated.
---
---   A `---` nested inside a Div is hoisted to the slide level: the
---   enclosing Div is closed, the heading chain is repeated, and an
---   identical Div is reopened around the content that follows. This works
---   for every Div except `.panel-tabset` and cross-reference targets
---   (a Div whose identifier looks like `tbl-…`, `fig-…`, `thm-…`, …),
---   and for reveal.js output only.
---   The full heading chain is always repeated in this case; the
---   heading-after-`---` shortening only applies at the top level.
---   When the Div opens with a heading, that heading is repeated inside
---   every reopened Div, so a callout titled by a heading keeps its title.
---
---   For non-reveal.js formats, behaviour depends on the `keep-hrule` option
---   (default: `false`).
---   When `false`, horizontal rules are removed from the output.
---
---   The filter runs at the `pre-ast` entry point, before Quarto normalises
---   the AST, so every Div is still a plain Div when the filter sees it.
---
---   A heading carrying the `no-cascade` class is never repeated on
---   continuation slides and is not carried in the parent chain for
---   subsequent `---` slides.
---
---   The `extensions.cascade.depth` option limits how many heading levels of
---   the chain are repeated on continuation slides (default: no limit).
---   When set to `N`, only the top `N` levels relative to the slide level are
---   cloned.
---   The `cascade-depth` heading attribute overrides the document-level
---   `depth` for the chain that starts at that heading.
---
---   When the cloned chain skips a heading level (for example, a `##`
---   followed by a `####` with no `###` in between), the filter emits a
---   warning. The output is still produced; the warning surfaces a source
---   structure that is likely accidental.
---
---   Headings below the slide level create section wrappers in reveal.js
---   output, so they are skipped when cloning the chain on `---` slides.
---   Quarto treats `shift-heading-level-by` as a pandoc option and applies it
---   after filters run, so no channel exposes it to this filter. A document
---   that sets it must declare the same value as `extensions.cascade.shift`,
---   which is subtracted from the writer's slide level to give the slide
---   level in AST coordinates.

local EXTENSION_NAME = 'cascade'
local DEPTH_ATTRIBUTE = 'cascade-depth'
local MAXIMUM_HEADING_LEVEL = 6

--- Load the shared logging module bundled with this extension.
local log = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))
local schema = require(quarto.utils.resolve_path('_vendor/quarto-wizard/schema.lua'):gsub('%.lua$', ''))
local check = require(quarto.utils.resolve_path('_vendor/quarto-lua-modules/schema-check.lua'):gsub('%.lua$', ''))

--- The schema check, built once and reused for the whole document. It reads
--- `_schema.yml` on the way in and checks the document configuration once.
---
--- The validator is injected rather than required by the check module, so the
--- two vendored sources stay independent of where the other was placed.
---
--- The extension contributes a filter and no shortcode, so the check runs from
--- the document handler, at the top, before the first option is read.
---
--- A schema that cannot be read is reported by the module as an error and the
--- render carries on: a configuration file must not stop a document.
local checker = check.new(schema, EXTENSION_NAME)

--- Read a raw `extensions.cascade.<key>` value from document metadata.
--- @param meta pandoc.Meta The document metadata.
--- @param key string The option name.
--- @return any|nil The metadata value, or `nil` when the option is unset.
local function get_option(meta, key)
  local extensions = meta['extensions']
  if not extensions then
    return nil
  end
  local cascade = extensions['cascade']
  if not cascade then
    return nil
  end
  return cascade[key]
end

--- Read the `keep-hrule` extension option from document metadata.
--- @param meta pandoc.Meta The document metadata.
--- @return boolean Whether to keep horizontal rules in non-reveal.js formats.
local function get_keep_hrule(meta)
  local keep = get_option(meta, 'keep-hrule')
  if keep == nil then
    return false
  end
  return pandoc.utils.stringify(keep) ~= 'false'
end

--- Read the `depth` extension option from document metadata.
--- Emits a warning and returns `nil` when the value is not a non-negative
--- integer.
--- @param meta pandoc.Meta The document metadata.
--- @return integer|nil The maximum number of heading levels to repeat, or
---   `nil` when no limit is set.
local function get_depth(meta)
  local raw = get_option(meta, 'depth')
  if raw == nil then
    return nil
  end
  local text = pandoc.utils.stringify(raw)
  local parsed = tonumber(text)
  if parsed == nil or parsed < 0 or parsed ~= math.floor(parsed) then
    log.log_warning(
      EXTENSION_NAME,
      'Ignoring "depth" option "' .. text .. '": expected a whole number of '
        .. 'zero or more. Repeating the whole chain.'
    )
    return nil
  end
  return parsed
end

--- Read the `shift` extension option from document metadata.
--- Emits a warning and returns `0` when the value is not a whole number.
--- @param meta pandoc.Meta The document metadata.
--- @return integer The heading level shift, or `0` when unset.
local function get_shift(meta)
  local raw = get_option(meta, 'shift')
  if raw == nil then
    return 0
  end
  local text = pandoc.utils.stringify(raw)
  local parsed = tonumber(text)
  if parsed == nil or parsed ~= math.floor(parsed) then
    log.log_warning(
      EXTENSION_NAME,
      'Ignoring "shift" option "' .. text .. '": expected a whole number.'
    )
    return 0
  end
  return parsed
end

--- Parse a per-heading `cascade-depth` attribute as a non-negative integer.
--- Returns `nil` when the attribute is absent. Emits a warning and returns
--- `nil` when the value is not a non-negative integer.
--- @param header pandoc.Header The heading.
--- @return integer|nil The parsed depth, or `nil` to fall back to the
---   document-level setting.
local function read_heading_depth(header)
  local resolved = checker:attributes(header.attributes, nil) or {}
  local written = header.attributes[DEPTH_ATTRIBUTE]
  header.attributes[DEPTH_ATTRIBUTE] = nil
  if written == nil then
    return nil
  end
  local value = resolved[DEPTH_ATTRIBUTE]
  local parsed = type(value) == 'number' and value or nil
  if parsed == nil or parsed < 0 or parsed ~= math.floor(parsed) then
    log.log_warning(
      EXTENSION_NAME,
      'Ignoring non-integer "' .. DEPTH_ATTRIBUTE .. '" on heading "'
        .. pandoc.utils.stringify(header.content) .. '": "' .. written .. '".'
    )
    return nil
  end
  return parsed
end

--- Detect the effective slide level in AST coordinates.
--- `PANDOC_WRITER_OPTIONS.slide_level` is the writer's (post-shift) slide
--- level. The AST still has pre-shift heading levels, so the AST slide
--- level is `slide_level - shift`, with the shift taken from the
--- `extensions.cascade.shift` option.
--- A shift that puts the result outside the range of a heading level makes
--- every chain empty, so no `---` would produce a slide break. That is
--- always a mistake in the option, so it is reported and the shift ignored.
--- @param meta pandoc.Meta The document metadata.
--- @return integer The slide level in AST coordinates.
local function detect_slide_level(meta)
  local slide_level = 2
  if PANDOC_WRITER_OPTIONS and PANDOC_WRITER_OPTIONS.slide_level then
    slide_level = PANDOC_WRITER_OPTIONS.slide_level
  end
  local shift = get_shift(meta)
  local ast_slide_level = slide_level - shift
  if ast_slide_level < 1 or ast_slide_level > MAXIMUM_HEADING_LEVEL then
    log.log_warning(
      EXTENSION_NAME,
      'Ignoring "shift" option ' .. shift .. ': it puts the slide level at '
        .. ast_slide_level .. ', outside the range 1 to '
        .. MAXIMUM_HEADING_LEVEL .. ', which would repeat no heading at all.'
    )
    return slide_level
  end
  return ast_slide_level
end

--- Split a list of blocks into pieces wherever a `HorizontalRule` occurs.
--- @param blocks pandoc.List The blocks to split.
--- @return table A list of block lists (one more than the number of rules).
--- @return boolean Whether at least one `HorizontalRule` was found.
local function split_blocks_at_horizontal_rule(blocks)
  local pieces = {}
  local current = {}
  local found = false
  for _, block in ipairs(blocks) do
    if block.t == 'HorizontalRule' then
      found = true
      table.insert(pieces, current)
      current = {}
    else
      table.insert(current, block)
    end
  end
  table.insert(pieces, current)
  return pieces, found
end

--- Warn when the cloned heading chain skips a level.
--- A non-contiguous chain (for example a `##` directly followed by a `####`
--- with no `###` between them) typically points to an accidental gap in
--- the source structure.
--- @param chain table The chain of headings about to be cloned.
local function warn_non_contiguous_chain(chain)
  for index = 2, #chain do
    local previous = chain[index - 1]
    local current = chain[index]
    if current.level > previous.level + 1 then
      log.log_warning(
        EXTENSION_NAME,
        'Heading chain skips from level ' .. previous.level
          .. ' ("' .. pandoc.utils.stringify(previous.content) .. '") '
          .. 'to level ' .. current.level
          .. ' ("' .. pandoc.utils.stringify(current.content) .. '") '
          .. 'on a continuation slide; intermediate level(s) are missing.'
      )
    end
  end
end

--- Hoist `---` out of a Div: when the Div directly contains one or more
--- `HorizontalRule`s, replace it with a sequence of clones of the Div, one
--- per non-empty fragment, separated by `HorizontalRule`s at the slide
--- level. The identifier is cleared on every clone after the first to avoid
--- duplicate IDs. When the Div opens with a heading, that heading is
--- repeated at the top of every clone after the first, so a callout titled
--- by a heading keeps its title on continuation slides.
--- Only applies to reveal.js output; `.panel-tabset` Divs and
--- cross-reference targets (identifier of the form `<type>-<label>`, e.g.
--- `tbl-results`, `fig-plot`, `thm-main`) are left untouched.
--- Parameter and return types are provided by the Quarto Lua plugin.
function Div(div)
  if not quarto.doc.is_format('revealjs') then
    return nil
  end
  if div.classes:includes('panel-tabset') then
    return nil
  end
  if div.identifier ~= '' and div.identifier:match('^%a+%-') then
    return nil
  end
  local pieces, found = split_blocks_at_horizontal_rule(div.content)
  if not found then
    return nil
  end
  local title = nil
  if div.content[1] and div.content[1].t == 'Header' then
    title = div.content[1]
  end
  local blocks = pandoc.Blocks({})
  for index, piece in ipairs(pieces) do
    local not_first = index > 1
    if not_first then
      blocks:insert(pandoc.HorizontalRule())
    end
    if #piece > 0 then
      local attr = div.attr:clone()
      local content = pandoc.Blocks(piece)
      if not_first then
        attr.identifier = ''
        if title then
          local clone = title:clone()
          clone.identifier = ''
          content:insert(1, clone)
        end
      end
      blocks:insert(pandoc.Div(content, attr))
    end
  end
  return blocks
end

--- Process the full document: detect the effective slide level, then
--- replace each `HorizontalRule` with clones of the heading chain
--- from the most recent slide.
--- Headings marked `.no-cascade` are excluded from the chain, and the
--- `depth` option (overridable per heading via `cascade-depth`) limits how
--- many heading levels of the chain are repeated.
--- For non-reveal.js formats, either keep or remove horizontal rules
--- based on the `keep-hrule` option.
--- Parameter and return types are provided by the Quarto Lua plugin.
function Pandoc(doc)
  checker:options(doc.meta)

  if not quarto.doc.is_format('revealjs') then
    local keep_hrule = get_keep_hrule(doc.meta)
    if keep_hrule then
      return doc
    end
    doc.blocks = doc.blocks:walk({
      HorizontalRule = function() return {} end,
    })
    return doc
  end

  local slide_level = detect_slide_level(doc.meta)
  local document_depth = get_depth(doc.meta)
  local parents = {}
  local chain = {}
  local active_depth = document_depth
  local at_slide_start = false
  local new_blocks = pandoc.Blocks({})

  for i, block in ipairs(doc.blocks) do
    if block.t == 'Header' and block.level < slide_level then
      local new_parents = {}
      for _, p in ipairs(parents) do
        if p.level < block.level then
          table.insert(new_parents, p)
        end
      end
      local per_heading_depth = read_heading_depth(block)
      if not block.classes:includes('no-cascade') then
        table.insert(new_parents, block)
      end
      parents = new_parents
      chain = {}
      active_depth = per_heading_depth or document_depth
      at_slide_start = false
      new_blocks:insert(block)
    elseif block.t == 'Header' and block.level == slide_level then
      chain = {}
      for _, p in ipairs(parents) do
        table.insert(chain, p)
      end
      local per_heading_depth = read_heading_depth(block)
      if not block.classes:includes('no-cascade') then
        table.insert(chain, block)
      end
      active_depth = per_heading_depth or document_depth
      at_slide_start = true
      new_blocks:insert(block)
    elseif at_slide_start and block.t == 'Header' then
      local per_heading_depth = read_heading_depth(block)
      if not block.classes:includes('no-cascade') then
        table.insert(chain, block)
      end
      if per_heading_depth ~= nil then
        active_depth = per_heading_depth
      end
      new_blocks:insert(block)
    elseif block.t == 'HorizontalRule' and #chain > 0 then
      local next_block = doc.blocks[i + 1]
      local next_is_header = next_block and next_block.t == 'Header'
      local new_chain = {}
      for _, h in ipairs(chain) do
        local within_depth = not active_depth or (h.level - slide_level) < active_depth
        if within_depth and h.level >= slide_level and (not next_is_header or h.level < next_block.level) then
          local clone = h:clone()
          clone.identifier = ''
          new_blocks:insert(clone)
          table.insert(new_chain, clone)
        end
      end
      warn_non_contiguous_chain(new_chain)
      chain = new_chain
      at_slide_start = true
    else
      at_slide_start = false
      new_blocks:insert(block)
    end
  end

  doc.blocks = new_blocks
  return doc
end
