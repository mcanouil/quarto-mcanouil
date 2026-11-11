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

local contrast_math = require('lib.contrast-math')
local preset = require('preset')

local M = {}

--- @type number Minimum ratio of text.
local TEXT = 4.5

--- @type number Minimum ratio of non-text elements: rules, edges, focus rings.
local NON_TEXT = 3.0

--- @type string[] Semantic colour tokens, which are also callout edges.
local SEMANTICS = { 'note', 'tip', 'warning', 'important', 'caution' }

--- Build the pair table.
--- @return table[] Rows of `name`, `fg_token`, `bg_token` and `threshold`
local function build_pairs()
  local rows = {}
  local function add(fg, bg, threshold)
    rows[#rows + 1] = { name = fg .. ' on ' .. bg, fg_token = fg, bg_token = bg, threshold = threshold }
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
  add('accent', 'paper', NON_TEXT)
  add('link', 'paper', NON_TEXT)
  for _, semantic in ipairs(SEMANTICS) do
    add(semantic, 'paper', NON_TEXT)
  end
  return rows
end

--- @type table[] Pairs to check, in the order they are reported.
M.PAIRS = build_pairs()

--- Check the pairs in each scheme.
--- @param pairs table[] Rows of `name`, `fg_token`, `bg_token` and `threshold`
--- @param get_colour fun(mode: string, token: string): string Hex colour of a token
--- @param modes string[] Schemes to check
--- @return table[] Failures, in order, each with `mode`, `ratio`, `threshold` and `message`
function M.check(pairs, get_colour, modes)
  local failures = {}
  for _, mode in ipairs(modes) do
    for _, pair in ipairs(pairs) do
      local ratio = contrast_math.ratio(get_colour(mode, pair.fg_token), get_colour(mode, pair.bg_token))
      if ratio < pair.threshold then
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
  local failures = M.check(M.PAIRS, function(mode, token) return tokens[mode][token] end, preset.resolve(meta).scheme_modes)
  if #failures > 0 then
    local lines = {}
    for index, failure in ipairs(failures) do
      lines[index] = 'mcanouil: contrast check failed: ' .. failure.message
    end
    io.stderr:write(table.concat(lines, '\n'), '\n')
    os.exit(1)
  end
end

--- @type table Filter step of the entry filter.
M.filter = { Meta = run }

return M
