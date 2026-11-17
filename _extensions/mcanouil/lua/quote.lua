--- @module "quote"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Attribution of block quotes in Typst
--- @description A block quote whose last paragraph starts with an em dash, an
--- en dash or `--` has an attribution. The dash is dropped, and the quote is
--- written as `#quote(block: true, attribution: [...])[...]`, so that the
--- Typst show rule styles the attribution. A quote without that paragraph is
--- left to Pandoc.

local fail = require('lib.fail')

local M = {}

--- @type string[] Dashes that mark an attribution, longest first.
M.DASHES = { '---', '--', '\u{2014}', '\u{2013}' }

--- Answer the text of a paragraph without its leading dash.
--- @param inlines pandoc.Inlines Content of the last paragraph
--- @return pandoc.Inlines|nil Attribution, or nil when the paragraph has no leading dash
function M.attribution(inlines)
  local first = inlines[1]
  if first == nil or first.t ~= 'Str' then
    return nil
  end
  for _, dash in ipairs(M.DASHES) do
    if first.text:sub(1, #dash) == dash then
      local rest = pandoc.Inlines(inlines:clone())
      local remainder = first.text:sub(#dash + 1)
      if remainder == '' then
        rest:remove(1)
      else
        rest[1] = pandoc.Str(remainder)
      end
      while rest[1] ~= nil and (rest[1].t == 'Space' or rest[1].t == 'SoftBreak') do
        rest:remove(1)
      end
      if #rest == 0 then
        fail.raise(
          'mcanouil: a block quote has a closing paragraph that holds only a dash; '
            .. 'write the source after the dash, for example "-- Name, 2026".'
        )
      end
      return rest
    end
  end
  return nil
end

--- Rewrite a block quote that has an attribution.
--- @param quote pandoc.BlockQuote Block quote
--- @return pandoc.Blocks|nil Raw Typst around the content, or nil to keep the quote
local function convert(quote)
  if not quote.content or #quote.content < 2 then
    return nil
  end
  local last = quote.content[#quote.content]
  if last.t ~= 'Para' then
    return nil
  end
  local attribution = M.attribution(last.content)
  if attribution == nil then
    return nil
  end
  local blocks = pandoc.Blocks({})
  blocks:insert(pandoc.RawBlock('typst', '#quote(block: true, attribution: ['))
  blocks:insert(pandoc.Plain(attribution))
  blocks:insert(pandoc.RawBlock('typst', '])['))
  for index = 1, #quote.content - 1 do
    blocks:insert(quote.content[index])
  end
  blocks:insert(pandoc.RawBlock('typst', ']'))
  return blocks
end

--- Answer a filter step that works for Typst only.
--- @param fn function Block quote function
--- @return function Function that skips every other format
local function typst_only(fn)
  return function(quote)
    if quarto.doc.is_format('typst') then
      return fn(quote)
    end
    return nil
  end
end

M.convert = convert

--- @type table Filter step of the entry filter.
M.filter = { BlockQuote = fail.guard(typst_only(convert)) }

return M
