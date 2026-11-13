--- @module "html-page"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Title block data and page footer of the HTML format
--- @description Delivers to the title block partial the corner motif of the
--- preset, the kicker and the author display, and adds the page footer with
--- its three slots. Runs for `mcanouil-html` only, after the preset step.

local fail = require('lib.fail')
local labels = require('lib.labels')
local motif = require('lib.motif')
local authors = require('authors')
local document = require('document')

--- @type string Directory of the extension, the parent of `lua/`.
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\][^/\\]+$')

local M = {}

--- @type table<string, string> Label key of the default kicker of each document type.
M.KICKERS = { report = 'mcanouil-report' }

--- Answer a motif as a CSS image for a mask: a data URL of the SVG with the
--- custom properties removed, since an image cannot read the custom properties
--- of the page. A mask reads only the alpha channel, so the shapes keep their
--- opacity and the page paints them in the colour it chooses.
--- @param name string Motif name, for example `facets`
--- @return string CSS `url()` value
function M.motif_mask(name)
  local svg = motif.svg(name)
    :gsub('var%(%-%-[%w%-]+,%s*([^)]+)%)', '%1')
    :gsub('currentColor', 'black')
    :gsub('%s+', ' ')
  local encoded = svg:gsub('[^%w%-%._~:/=,;]', function(char)
    return string.format('%%%02X', char:byte())
  end)
  return 'url("data:image/svg+xml,' .. encoded .. '")'
end

--- Answer the kicker of a document: the `kicker` metadata, or the label of the
--- document type when the type has one, as in the Typst title block.
--- @param meta table Document metadata
--- @return any|nil Kicker inlines, or nil
local function kicker(meta)
  if meta.kicker ~= nil then
    return meta.kicker
  end
  local options = meta.extensions and meta.extensions.mcanouil or {}
  local doc_type = options.type and pandoc.utils.stringify(options.type) or document.DEFAULT_TYPE
  local key = M.KICKERS[doc_type]
  return key and pandoc.MetaInlines({ pandoc.Str(labels.get(key)) }) or nil
end

--- Answer the HTML of some inlines.
--- @param inlines pandoc.Inlines
--- @return string HTML
local function inline_html(inlines)
  return (pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), 'html'):gsub('%s+$', ''))
end

--- Answer the page footer: the three footer slots of the document type, or
--- nil when every slot is empty. A slot that only Typst can fill, such as the
--- page number, is empty in HTML.
--- @param meta table Document metadata
--- @return string|nil HTML
function M.footer(meta)
  local slots = document.furniture(meta).footer
  local parts, filled = {}, false
  for _, slot in ipairs(document.SLOTS) do
    local content = inline_html(document.resolve_slot(slots[slot], meta))
    filled = filled or content ~= ''
    parts[#parts + 1] = '<div class="mc-slot mc-slot-' .. slot .. '">' .. content .. '</div>'
  end
  if not filled then
    return nil
  end
  return '<footer class="mc-page-footer page-columns page-full"><div class="mc-slots">'
    .. table.concat(parts) .. '</div></footer>'
end

--- Deliver the title block data and add the page footer.
--- @param meta table Document metadata
--- @return table Metadata
local function deliver(meta)
  if not quarto.doc.is_format('html') or quarto.doc.is_format('revealjs') then
    return meta
  end
  if meta['mcanouil-motif'] ~= nil then
    local svg = motif.svg(pandoc.utils.stringify(meta['mcanouil-motif']))
    meta['mcanouil-motif-svg'] = pandoc.MetaBlocks({ pandoc.RawBlock('html', svg) })
    quarto.doc.include_text('in-header', '<style id="mcanouil-motif-mask">:root { --mc-motif-mask: '
      .. M.motif_mask(pandoc.utils.stringify(meta['mcanouil-motif'])) .. '; }</style>')
  end
  meta['mcanouil-kicker'] = kicker(meta)
  -- A book or a website page has Quarto's header as its banner landmark, so
  -- the title block is not a second banner: its text is a region named by
  -- the title.
  if meta.book ~= nil or meta.website ~= nil then
    meta['mcanouil-site'] = true
  end
  local collected = authors.collect(meta)
  if collected ~= nil then
    meta['mcanouil-authors-html'] = pandoc.MetaBlocks({ pandoc.RawBlock('html', authors.html(collected, labels.get)) })
  end
  local footer = M.footer(meta)
  if footer ~= nil then
    quarto.doc.include_text('after-body', footer)
  end
  return meta
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = fail.guard(deliver) }

return M
