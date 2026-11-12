--- @module "contrast"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Render-time contrast check of the colour tokens
--- @description Checks the merged tokens of the document against WCAG AA before
--- anything is delivered, and stops the render with the first failing pair.
--- The pairs are data, one row each, so later steps can add rows.

--- @type string Directory of this file, searched for the sibling modules.
local LUA_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\][^/\\]+$')

package.path = LUA_DIR .. '/?.lua;' .. package.path

local fail = require('lib.fail')
local contrast_math = require('lib.contrast-math')
local preset = require('preset')

local M = {}

--- @type number Minimum ratio of text.
local TEXT = 4.5

--- @type number Minimum ratio of non-text elements: rules, edges, focus rings.
local NON_TEXT = 3.0

--- @type number Minimum ratio of large text, such as the chapter number of a divider page.
local LARGE_TEXT = 3.0

--- @type string[] Semantic colour tokens, which are also callout edges.
local SEMANTICS = { 'note', 'tip', 'warning', 'important', 'caution' }

--- Build the pair table.
--- @return table[] Rows of `name`, `fg_token`, `bg_token`, `threshold` and, for a pair of one preset, `only`, and for a pair of one scheme, `mode` (a `label` names the row)
local function build_pairs()
  local rows = {}
  local function add(fg, bg, threshold, only, label, mode)
    rows[#rows + 1] = {
      name = label or (fg .. ' on ' .. bg), fg_token = fg, bg_token = bg, threshold = threshold, only = only, mode = mode,
    }
  end
  for _, fg in ipairs({ 'ink', 'muted', 'link', 'accent-text' }) do
    add(fg, 'paper', TEXT)
    add(fg, 'tint', TEXT)
  end
  for _, semantic in ipairs(SEMANTICS) do
    add(semantic .. '-text', 'paper', TEXT)
    add(semantic .. '-text', 'tint', TEXT)
  end
  for _, fg in ipairs({ 'on-ground-text', 'on-ground-accent', 'on-ground-title' }) do
    add(fg, 'ground-1', TEXT)
    add(fg, 'ground-2', TEXT)
  end
  add('on-ground-title', 'chrome', TEXT)
  add('ink', 'card', TEXT)
  add('muted', 'card', TEXT)
  add('accent-text', 'card', TEXT)
  add('paper', 'accent', TEXT, 'mono', 'quote-label: paper on accent')
  add('paper', 'accent-text', TEXT, nil, 'code annotation: paper on accent-text')
  add('ground-1', 'on-ground-accent', TEXT, 'mono', 'deck kicker: ground-1 on on-ground-accent')
  add('on-ground-text', 'paper', TEXT, nil, 'deck footer on a dark slide: on-ground-text on paper', 'dark')
  add('muted', 'paper', NON_TEXT, nil, 'deck menu button: muted on paper')
  add('on-ground-text', 'ground-1', NON_TEXT, nil, 'deck menu button: on-ground-text on ground-1')
  add('on-ground-text', 'ground-2', NON_TEXT, nil, 'deck menu button: on-ground-text on ground-2')
  add('on-ground-text', 'paper', NON_TEXT, nil, 'deck menu button on a dark slide: on-ground-text on paper', 'dark')
  for _, fg in ipairs({ 'ink', 'muted', 'link', 'accent-text' }) do
    add(fg, 'ground-2', TEXT, 'terminal', 'deck slide: ' .. fg .. ' on ground-2')
  end
  add('accent-high', 'ground-1', LARGE_TEXT)
  add('accent-high', 'ground-2', LARGE_TEXT)
  add('accent-high', 'paper', LARGE_TEXT, 'terminal', 'decoration: accent-high on paper')
  add('accent', 'paper', NON_TEXT)
  add('link', 'paper', NON_TEXT)
  add('link', 'card', NON_TEXT, nil, 'focus ring: link on card')
  for _, semantic in ipairs(SEMANTICS) do
    add(semantic, 'paper', NON_TEXT)
  end
  return rows
end

--- @type table[] Pairs to check, in the order they are reported.
M.PAIRS = build_pairs()

--- Check the pairs in each scheme.
--- @param pairs table[] Rows of `name`, `fg_token`, `bg_token`, `threshold` and optionally `only`, the preset the pair applies to, and `mode`, the scheme it applies to
--- @param get_colour fun(mode: string, token: string): string Hex colour of a token
--- @param modes string[] Schemes to check
--- @param preset_name string|nil Preset of the document; a pair with `only` is skipped for the others
--- @return table[] Failures, in order, each with `mode`, `ratio`, `threshold` and `message`
function M.check(pairs, get_colour, modes, preset_name)
  local failures = {}
  for _, mode in ipairs(modes) do
    for _, pair in ipairs(pairs) do
      local ratio = contrast_math.ratio(get_colour(mode, pair.fg_token), get_colour(mode, pair.bg_token))
      local applies = (pair.only == nil or pair.only == preset_name) and (pair.mode == nil or pair.mode == mode)
      if applies and ratio < pair.threshold then
        failures[#failures + 1] = {
          mode = mode,
          ratio = ratio,
          threshold = pair.threshold,
          message = string.format(
            '%s (%s) is %.2f:1, below %.2f:1. Change %s or %s in _brand.yml.',
            pair.name, mode, ratio, pair.threshold, pair.fg_token, pair.bg_token
          ),
        }
      end
    end
  end
  return failures
end

--- Check the merged tokens of a document, and stop the render on a failure.
--- @param meta table Document metadata
local function run(meta)
  local tokens = preset.tokens(meta)
  local resolved = preset.resolve(meta)
  local failures = M.check(M.PAIRS, function(mode, token) return tokens[mode][token] end, resolved.scheme_modes, resolved.name)
  if #failures > 0 then
    local lines = {}
    for index, failure in ipairs(failures) do
      lines[index] = 'mcanouil: contrast check failed: ' .. failure.message
    end
    fail.stop(table.concat(lines, '\n'))
  end
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = fail.guard(run) }

return M
