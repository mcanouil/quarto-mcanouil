--- @module "preset"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Preset selection, token merge and token delivery
--- @description Reads the preset named by `extensions.mcanouil.preset` from `presets/`,
--- merges the user `_brand.yml` over it (the user value wins), and delivers one
--- token table per scheme: CSS custom properties for HTML and Reveal.js, and
--- metadata for Typst.

--- @type string Directory of the extension, the parent of `lua/`.
local fail = require('lib.fail')
local EXTENSION_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\]lua[/\\][^/\\]+$')

local colour = dofile(EXTENSION_DIR .. '/_vendor/quarto-lua-modules/colour.lua')

local M = {}

--- @type string[] Preset names, in the order of the error message.
M.PRESETS = { 'gold', 'mono', 'quarto', 'terminal' }

--- @type string Preset used when `extensions.mcanouil.preset` is not set.
M.DEFAULT = 'gold'

--- @type string[] Colour tokens of every preset, in each scheme.
M.TOKENS = {
  'paper', 'ink', 'muted', 'tint', 'line',
  'accent', 'accent-high', 'accent-low', 'accent-text', 'link',
  'ground-1', 'ground-2', 'on-ground-accent', 'on-ground-text', 'on-ground-title', 'chrome',
  'note', 'tip', 'warning', 'important', 'caution',
  'note-text', 'tip-text', 'warning-text', 'important-text', 'caution-text',
}

--- @type string[] Font roles of every preset, as in `_brand.yml` typography.
M.FONT_ROLES = { 'base', 'headings', 'monospace' }

--- @type table<string, string> CSS custom property of each font role.
M.FONT_VARIABLES = { base = '--mc-font-base', headings = '--mc-font-headings', monospace = '--mc-font-mono' }

--- @type string Class of the Reveal.js slides that use the dark ground.
M.GROUND_CLASS = 'mc-ground'

--- @type table<string, boolean> Presets that have a dark scheme only.
M.DARK_ONLY = { terminal = true }

--- @type string Warning for a light request with a dark only preset.
M.DARK_ONLY_WARNING = 'mcanouil: the terminal preset is dark only; brand-mode: light is ignored.'

--- @type table<string, boolean> CSS generic families, which Typst does not know.
local GENERIC_FAMILIES = {
  serif = true, ['sans-serif'] = true, monospace = true, cursive = true, fantasy = true,
  ['system-ui'] = true, ['ui-serif'] = true, ['ui-sans-serif'] = true, ['ui-monospace'] = true,
}

--- @type string[] Schemes, in output order.
local MODES = { 'light', 'dark' }

--- @type table<string, string> `_brand.yml` colour role of a token, when it is not the token name.
local BRAND_ROLE = { accent = 'primary', paper = 'background', ink = 'foreground' }

--- Convert a Pandoc metadata value to plain Lua tables and strings.
--- @param value any Metadata value
--- @return any Plain value
local function plain(value)
  local value_type = pandoc.utils.type(value)
  if value_type == 'table' or value_type == 'Meta' then
    local result = {}
    for key, item in pairs(value) do
      result[key] = plain(item)
    end
    return result
  end
  return pandoc.utils.stringify(value)
end

--- Convert a CSS colour to a lower case 6-digit hex value.
--- @param value string CSS colour: hex, `rgb()` or a named colour
--- @param role string Brand role, for the error message
--- @param mode string Scheme, for the error message
--- @return string Hex colour, lower case, six digits
local function to_hex(value, role, mode)
  local compact = value:lower():gsub('%s', '')
  if compact:match('^#%x%x%x$') or compact:match('^#%x%x%x%x%x%x$') then
    return colour.expand_hex_colour(compact)
  end
  if colour.is_named_colour(compact) then
    return colour.named_to_HTML(compact):lower()
  end
  if compact:match('^rgb%(%d+,%d+,%d+%)$') then
    return colour.RGB_to_HTML(compact):lower()
  end
  fail.stop(string.format(
    'mcanouil: cannot read the colour "%s" of the brand role "%s" (%s); use a hex value, rgb() or a CSS colour name.',
    value, role, mode
  ))
end

--- Check a preset name, or answer the default.
--- @param name string|nil Preset name from the metadata
--- @return string Preset name
function M.resolve_name(name)
  if name == nil or name == '' then
    return M.DEFAULT
  end
  for _, known in ipairs(M.PRESETS) do
    if name == known then
      return name
    end
  end
  fail.stop(string.format(
    'mcanouil: unknown preset "%s" in extensions.mcanouil.preset; use one of %s.',
    name, table.concat(M.PRESETS, ', ')
  ))
end

--- Read a preset data file.
--- @param name string Preset name
--- @return table Preset data: `light`, `dark`, `fonts`, `motif` and `logo`
function M.read(name)
  local path = EXTENSION_DIR .. '/presets/' .. name .. '.yml'
  local file = io.open(path, 'r')
  if not file then
    fail.stop('mcanouil: cannot open the preset file ' .. path .. '.')
  end
  local text = file:read('a')
  file:close()
  return plain(pandoc.read('---\n' .. text .. '\n---\n', 'markdown').meta)
end

--- Merge user colours over the preset colours, one table per scheme.
--- @param data table Preset data from `M.read`
--- @param user_colour fun(mode: string, role: string): string|nil User colour of a brand role
--- @return table<string, table<string, string>> Hex colour of each token, by scheme
function M.merge(data, user_colour)
  local tokens = {}
  for _, mode in ipairs(MODES) do
    tokens[mode] = {}
    for _, token in ipairs(M.TOKENS) do
      local role = BRAND_ROLE[token] or token
      local value = user_colour(mode, role)
      tokens[mode][token] = value and to_hex(value, role, mode) or data[mode][token]
    end
  end
  return tokens
end

--- Answer the preset name of a document and the schemes it supports.
--- @param meta table Document metadata
--- @return table `name` and `scheme_modes`
function M.resolve(meta)
  local options = meta.extensions and meta.extensions.mcanouil
  local name = M.resolve_name(options and options.preset and pandoc.utils.stringify(options.preset))
  return { name = name, scheme_modes = M.DARK_ONLY[name] and { 'dark' } or { 'light', 'dark' } }
end

--- Merge the user brand colours over a preset. A dark only preset answers
--- its dark table for both schemes.
--- @param name string Preset name
--- @param data table Preset data from `M.read`
--- @return table<string, table<string, string>> Hex colour of each token, by scheme
local function brand_tokens(name, data)
  local tokens = M.merge(data, quarto.brand.get_color_css)
  if M.DARK_ONLY[name] then
    tokens.light = tokens.dark
  end
  return tokens
end

--- Merge the user brand font families over a preset, by scheme. Each entry
--- holds the `family` (a family or a CSS stack) and the preset `generic` family.
--- @param name string Preset name
--- @param data table Preset data from `M.read`
--- @return table<string, table<string, table>> Font of each role, by scheme
local function brand_fonts(name, data)
  local fonts = {}
  for _, mode in ipairs(MODES) do
    fonts[mode] = {}
    for _, role in ipairs(M.FONT_ROLES) do
      local user = quarto.brand.get_typography(mode, role)
      fonts[mode][role] = {
        family = (user and user.family) or data.fonts[role],
        generic = data.fonts.generic[role],
      }
    end
  end
  if M.DARK_ONLY[name] then
    fonts.light = fonts.dark
  end
  return fonts
end

--- Answer the merged colour tokens of a document.
--- @param meta table Document metadata
--- @return table<string, table<string, string>> Hex colour of each token, by scheme
function M.tokens(meta)
  local name = M.resolve(meta).name
  return brand_tokens(name, M.read(name))
end

--- Answer the merged fonts of a document.
--- @param meta table Document metadata
--- @return table<string, table<string, table>> Font of each role, by scheme
function M.fonts(meta)
  local name = M.resolve(meta).name
  return brand_fonts(name, M.read(name))
end

--- Answer the scheme of a single-scheme output (Typst, Reveal.js), from
--- `brand-mode`. A dark only preset ignores a light request with a warning.
--- @param meta table Document metadata
--- @param name string Preset name
--- @return string Scheme, `light` or `dark`
local function render_mode(meta, name)
  local requested = meta['brand-mode'] and pandoc.utils.stringify(meta['brand-mode'])
  if M.DARK_ONLY[name] then
    if requested == 'light' then
      quarto.log.warning(M.DARK_ONLY_WARNING)
    end
    return 'dark'
  end
  return requested == 'dark' and 'dark' or 'light'
end

--- Format a font family as a CSS value. A single family is quoted and
--- followed by the generic family; a CSS stack is kept as it is.
--- @param family string Font family or CSS font stack
--- @param generic string CSS generic family, for example `serif`
--- @return string CSS value
function M.css_family(family, generic)
  if family:find(',', 1, true) then
    return family
  end
  return '"' .. family .. '", ' .. generic
end

--- Split a CSS font stack into the family names Typst can use: quotes and
--- CSS generic families are removed.
--- @param family string Font family or CSS font stack
--- @return string[] Family names
function M.typst_families(family)
  local families = {}
  for part in family:gmatch('[^,]+') do
    local name = part:gsub('^%s+', ''):gsub('%s+$', ''):gsub('^["\']', ''):gsub('["\']$', '')
    if name ~= '' and not GENERIC_FAMILIES[name:lower()] then
      families[#families + 1] = name
    end
  end
  return families
end

--- Build the CSS declarations of one scheme.
--- @param tokens table<string, string> Hex colour of each token
--- @param fonts table<string, table> Font of each role, from `brand_fonts`
--- @return string Declarations, on one line
local function declarations(tokens, fonts)
  local parts = {}
  for _, token in ipairs(M.TOKENS) do
    parts[#parts + 1] = '--mc-' .. token .. ': ' .. tokens[token] .. ';'
  end
  for _, role in ipairs(M.FONT_ROLES) do
    parts[#parts + 1] = M.FONT_VARIABLES[role] .. ': ' .. M.css_family(fonts[role].family, fonts[role].generic) .. ';'
  end
  return table.concat(parts, ' ')
end

--- Add the local font files and their `@font-face` rules to an HTML output.
local function add_fonts_dependency()
  local fonts_dir = EXTENSION_DIR .. '/fonts'
  local resources = {}
  for _, file in ipairs(pandoc.system.list_directory(fonts_dir)) do
    if file:match('%.woff2$') then
      resources[#resources + 1] = { name = file, path = fonts_dir .. '/' .. file }
    end
  end
  table.sort(resources, function(a, b) return a.name < b.name end)
  quarto.doc.add_html_dependency({
    name = 'mcanouil-fonts',
    version = '1.0.0',
    stylesheets = { fonts_dir .. '/fonts.css' },
    resources = resources,
  })
end

--- Deliver the tokens: CSS custom properties for HTML and Reveal.js,
--- metadata for Typst.
--- @param meta table Document metadata
--- @return table Metadata
local function deliver(meta)
  local name = M.resolve(meta).name
  local data = M.read(name)
  local tokens = brand_tokens(name, data)
  local fonts = brand_fonts(name, data)
  if quarto.doc.is_format('revealjs') then
    local mode = render_mode(meta, name)
    add_fonts_dependency()
    quarto.doc.include_text('in-header', table.concat({
      '<style id="mcanouil-tokens">',
      ':root { ' .. declarations(tokens[mode], fonts[mode]) .. ' }',
      '.reveal .slides section.dark, .reveal .slides section.' .. M.GROUND_CLASS .. ' { '
        .. declarations(tokens.dark, fonts.dark) .. ' }',
      '</style>',
    }, '\n'))
  elseif quarto.doc.is_format('html') then
    render_mode(meta, name)
    add_fonts_dependency()
    quarto.doc.include_text('in-header', table.concat({
      '<style id="mcanouil-tokens">',
      'body.quarto-light { ' .. declarations(tokens.light, fonts.light) .. ' }',
      'body.quarto-dark { ' .. declarations(tokens.dark, fonts.dark) .. ' }',
      '</style>',
    }, '\n'))
  elseif quarto.doc.is_format('typst') then
    local mode = render_mode(meta, name)
    local typst_tokens = {}
    for token, value in pairs(tokens[mode]) do
      typst_tokens[token] = value:sub(2)
    end
    meta['mcanouil-mode'] = mode
    meta['mcanouil-tokens'] = typst_tokens
    local typst_fonts = {}
    for role, font in pairs(fonts[mode]) do
      typst_fonts[role] = M.typst_families(font.family)
    end
    meta['mcanouil-fonts'] = typst_fonts
    meta['mcanouil-motif'] = data.motif
  end
  return meta
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = deliver }

return M
