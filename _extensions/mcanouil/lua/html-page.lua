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
local authors = require('authors')
local document = require('document')

--- @type string Directory of the extension, the parent of `lua/`.
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\][^/\\]+$')

local M = {}

--- @type table<string, string> Label key of the default kicker of each document type.
M.KICKERS = { report = 'mcanouil-report' }

--- Read the SVG file of a motif.
--- @param motif string Motif name, for example `facets`
--- @return string SVG markup
function M.motif_svg(motif)
  local path = EXTENSION_DIR .. '/html/motifs/' .. motif .. '.svg'
  local file = io.open(path, 'r')
  if not file then
    fail.raise('mcanouil: cannot open the motif file ' .. path .. '.')
  end
  local svg = file:read('a')
  file:close()
  return (svg:gsub('%s+$', ''))
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
    local svg = M.motif_svg(pandoc.utils.stringify(meta['mcanouil-motif']))
    meta['mcanouil-motif-svg'] = pandoc.MetaBlocks({ pandoc.RawBlock('html', svg) })
  end
  meta['mcanouil-kicker'] = kicker(meta)
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
