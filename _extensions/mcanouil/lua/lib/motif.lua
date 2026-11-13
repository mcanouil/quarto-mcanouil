--- @module "motif"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief SVG markup of the corner motifs for HTML pages and Reveal.js decks
--- @description Reads the SVG file of a motif from `html/motifs/`. A page that
--- shows more than one copy of a motif gives each copy a suffix, which is added
--- to every identifier in the SVG and to every `url(#...)` reference to it, so
--- that each copy keeps its own gradient: in a deck, a slide that Reveal.js
--- hides would otherwise hide the gradient of the next copies.

local fail = require('lib.fail')

--- @type string Directory of the extension, the parent of `lua/`.
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\]lib[/\\][^/\\]+$')

local M = {}

--- Read the SVG file of a motif.
--- @param name string Motif name, for example `facets`
--- @return string SVG markup
local function read(name)
  local path = EXTENSION_DIR .. '/html/motifs/' .. name .. '.svg'
  local file = io.open(path, 'r')
  if not file then
    fail.raise('mcanouil: cannot open the motif file ' .. path .. '.')
  end
  local svg = file:read('a')
  file:close()
  return svg
end

--- Add a suffix to every identifier of an SVG and to the references to it.
--- @param svg string SVG markup
--- @param suffix string Suffix of the identifiers
--- @return string SVG markup
local function suffix_ids(svg, suffix)
  local ids = {}
  for id in svg:gmatch('id="([^"]+)"') do
    ids[#ids + 1] = id
  end
  for _, id in ipairs(ids) do
    local escaped = id:gsub('%p', '%%%0')
    svg = svg:gsub('id="' .. escaped .. '"', 'id="' .. id .. '-' .. suffix .. '"')
      :gsub('url%(#' .. escaped .. '%)', 'url(#' .. id .. '-' .. suffix .. ')')
  end
  return svg
end

--- Answer the SVG markup of a motif.
--- @param name string Motif name, for example `facets`
--- @param suffix string|nil Suffix of the identifiers, for a page with more than one copy; nil keeps them as written
--- @return string SVG markup
function M.svg(name, suffix)
  local svg = read(name)
  if suffix ~= nil then
    svg = suffix_ids(svg, suffix)
  end
  return (svg:gsub('%s+$', ''))
end

return M
