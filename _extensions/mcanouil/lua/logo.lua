--- @module "logo"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Logo of the document, for Typst
--- @description Merges the logo of the user brand over the logo of the preset
--- (the user logo wins, the preset fills in), warns when the user logo has no
--- alt text, and delivers the logo to Typst as the `mcanouil-logo` metadata.

local fail = require('lib.fail')
local labels = require('lib.labels')
local preset = require('preset')

--- @type string Directory of the extension, the parent of `lua/`.
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\][^/\\]+$')

local M = {}

--- @type string[] Logo sizes of a brand, in order of preference.
M.SIZES = { 'medium', 'large', 'small' }

--- @type table<string, string> Typst image format of each file extension.
local FORMATS = { svg = 'svg', png = 'png', jpg = 'jpg', jpeg = 'jpg', gif = 'gif', webp = 'webp' }

--- Answer the Typst image format of a file.
--- @param path string Logo file
--- @return string Format: `svg`, `png`, `jpg`, `gif` or `webp`
function M.format_of(path)
  local format = FORMATS[(path:match('%.([^./\\]+)$') or ''):lower()]
  if format == nil then
    fail.stop(string.format('mcanouil: the logo "%s" must be an svg, png, jpg, gif or webp file.', path))
  end
  return format
end

--- Format the bytes of a string as a Typst array of integers.
--- @param content string Bytes
--- @return string Typst array
function M.bytes_literal(content)
  return '(' .. table.concat({ content:byte(1, -1) }, ', ') .. ',)'
end

--- Answer the place of a logo file.
--- @param path string Path as the brand gives it: absolute, or relative to the project
--- @param project string|nil Project directory
--- @return string Path to open
function M.locate(path, project)
  if path:sub(1, 1) == '/' or project == nil then
    return path
  end
  return project .. '/' .. path
end

--- Read a file.
--- @param path string File
--- @return string Content
local function read_file(path)
  local file = io.open(path, 'rb')
  if not file then
    fail.stop('mcanouil: cannot open the logo file ' .. path .. '.')
  end
  local content = file:read('a')
  file:close()
  return content
end

--- Answer the file name of a path.
--- @param path string Path
--- @return string File name
local function basename(path)
  return path:match('([^/\\]+)$') or path
end

--- Answer the logo of the user brand for a scheme.
--- @param mode string `light` or `dark`
--- @return table|nil `path` and `alt` of the first size the brand sets
local function user_logo(mode)
  for _, size in ipairs(M.SIZES) do
    local found = quarto.brand.get_logo(mode, size)
    if found ~= nil and found.path ~= nil then
      return found
    end
  end
  return nil
end

--- Merge the logo of the user brand over the logo of the preset.
--- @param name string Preset name
--- @param mode string `light` or `dark`
--- @return table `file` (path to open), `name` (file name), `alt`, and `user` (true for a brand logo)
function M.merged(name, mode)
  local user = user_logo(mode)
  if user ~= nil then
    local project = quarto.project and quarto.project.directory
    return {
      file = M.locate(pandoc.utils.stringify(user.path), project),
      name = basename(pandoc.utils.stringify(user.path)),
      alt = user.alt and pandoc.utils.stringify(user.alt) or '',
      user = true,
    }
  end
  local logo = preset.read(name).logo
  return { file = EXTENSION_DIR .. '/' .. logo[mode], name = basename(logo[mode]), alt = logo.alt, user = false }
end

--- Deliver the logo to Typst as the `mcanouil-logo` metadata.
--- @param meta table Document metadata
--- @return table Metadata
local function deliver(meta)
  if not quarto.doc.is_format('typst') then
    return meta
  end
  local logo = M.merged(preset.resolve(meta).name, pandoc.utils.stringify(meta['mcanouil-mode']))
  if logo.user and logo.alt == '' then
    quarto.log.warning(string.format(
      'mcanouil: the logo "%s" has no alt text. Add alt to the logo in _brand.yml.', logo.name
    ))
  end
  local function raw(code)
    return pandoc.MetaInlines({ pandoc.RawInline('typst', code) })
  end
  meta['mcanouil-logo'] = {
    bytes = raw(M.bytes_literal(read_file(logo.file))),
    format = raw(labels.typst_string(M.format_of(logo.file))),
    alt = raw(labels.typst_string(logo.alt)),
  }
  return meta
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = deliver }

return M
