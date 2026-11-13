--- @module "quote"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Attribution of block quotes in Typst, HTML and Reveal.js
--- @description A block quote whose last paragraph starts with an em dash, an
--- en dash or `--` has an attribution, and the dash is dropped. In Typst, the
--- quote is written as `#quote(block: true, attribution: [...])[...]`, so that
--- the Typst show rule styles the attribution; a quote without that paragraph
--- is left to Pandoc. In HTML, every quote is written as
--- `<figure class="mc-quote" data-mc-label="..."><blockquote>...</blockquote>`,
--- and the attribution, when there is one, as the caption of the figure,
--- `<figcaption class="mc-quote-attribution">`, so that it is announced as the
--- source, not as quoted text. The label is for the decoration that the
--- preset style sheet draws as generated content with an empty alternative
--- text. A GitHub alert (`> [!NOTE]`) is left to Quarto, which makes it a
--- callout. Reveal.js decks use the same figure.

local fail = require('lib.fail')
local labels = require('lib.labels')

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

--- Escape a string for an HTML attribute value.
--- @param text string
--- @return string
local function escape_attribute(text)
  return (text:gsub('&', '&amp;'):gsub('"', '&quot;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

--- Answer whether a block quote is a GitHub alert, such as `> [!NOTE]`.
--- @param quote pandoc.BlockQuote Block quote
--- @return boolean
local function is_alert(quote)
  local first = quote.content[1]
  if first == nil or (first.t ~= 'Para' and first.t ~= 'Plain') then
    return false
  end
  return pandoc.utils.stringify(first.content):match('^%[!%a+%]') ~= nil
end

--- Rewrite a block quote as an HTML figure: the quote, then its attribution,
--- when it has one, as the caption. The figure carries the label of the
--- decoration in `data-mc-label`. HTML pages and Reveal.js decks use it.
--- @param quote pandoc.BlockQuote Block quote
--- @param label string Text of the quote label, for example `Quote`
--- @return pandoc.Blocks|nil Raw HTML around the content, or nil to keep the quote (a GitHub alert)
function M.html(quote, label)
  if not quote.content or #quote.content == 0 or is_alert(quote) then
    return nil
  end
  local data = ' data-mc-label="' .. escape_attribute(label) .. '"'
  local last = quote.content[#quote.content]
  local attribution = nil
  if #quote.content >= 2 and last.t == 'Para' then
    attribution = M.attribution(last.content)
  end
  local blocks = pandoc.Blocks({ pandoc.RawBlock('html', '<figure class="mc-quote"' .. data .. '>\n<blockquote>') })
  local body_end = attribution and #quote.content - 1 or #quote.content
  for index = 1, body_end do
    blocks:insert(quote.content[index])
  end
  blocks:insert(pandoc.RawBlock('html', '</blockquote>'))
  if attribution then
    blocks:insert(pandoc.RawBlock('html', '<figcaption class="mc-quote-attribution"' .. data .. '>'))
    blocks:insert(pandoc.Plain(attribution))
    blocks:insert(pandoc.RawBlock('html', '</figcaption>'))
  end
  blocks:insert(pandoc.RawBlock('html', '</figure>'))
  return blocks
end

--- Rewrite a block quote for the output format: Typst, or HTML, which
--- includes Reveal.js. Other formats keep the quote.
--- @param quote pandoc.BlockQuote Block quote
--- @return pandoc.Blocks|nil
local function rewrite(quote)
  if quarto.doc.is_format('typst') then
    return convert(quote)
  end
  if quarto.doc.is_format('html') then
    return M.html(quote, labels.get('mcanouil-quote'))
  end
  return nil
end

M.convert = convert

--- @type table Filter step of the entry filter.
M.filter = { BlockQuote = fail.guard(rewrite) }

return M
