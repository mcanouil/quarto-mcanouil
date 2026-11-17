--- Typst Extras - Maths alt text
--- @module "math-alt"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Give unlabelled maths an alt text.
--- @description Turns the `alt` attribute of a Span or Div that holds only maths into `#math.equation(.., alt: ..)`.
---   Labelled equations are left to Quarto.
---   In other formats the `alt` attribute is removed.
---   A wrapper that carries nothing but `alt` is removed too, so the maths stays as it was;
---   a wrapper with an identifier, a class or another attribute is kept.

local emit = require(quarto.utils.resolve_path('_modules/emit.lua'):gsub('%.lua$', ''))

local M = {}

--- This module also acts outside Typst output, where it removes the wrapper.
M.all_formats = true

--- Prefix of the identifier of a Quarto equation.
local EQUATION_PREFIX = 'eq-'

--- Replace curly quotes by straight quotes, as Quarto does for equations.
--- @param text string The alt text
--- @return string
local function straighten(text)
  local straight = text:gsub('\u{201C}', '"'):gsub('\u{201D}', '"')
  straight = straight:gsub('\u{2018}', "'"):gsub('\u{2019}', "'")
  return straight
end

--- Closing of the equation call, which takes the body of the maths.
--- The maths is passed as `.body`, so one source equation gives one `math.equation` element.
M.CLOSE_CALL = '.body)'

--- Build the Typst text that opens an equation with an alt text.
--- @param block boolean Whether the equation is a display equation
--- @param alt string The alt text
--- @return string
function M.open_call(block, alt)
  return '#math.equation(block: ' .. tostring(block) .. ', alt: ' .. emit.string(straighten(alt)) .. ', '
end

--- Tell whether an element carries an alt text and is not a Quarto equation.
--- @param element pandoc.Span|pandoc.Div
--- @return boolean
local function is_candidate(element)
  local alt = element.attributes['alt']
  return alt ~= nil and alt ~= '' and element.identifier:sub(1, #EQUATION_PREFIX) ~= EQUATION_PREFIX
end

--- Return the only maths of an inline list, if the list holds nothing else.
--- @param inlines pandoc.Inlines
--- @return pandoc.Math|nil
local function only_math(inlines)
  if #inlines == 1 and inlines[1].t == 'Math' then
    return inlines[1]
  end
  return nil
end

--- Return the only display maths of a Div, if the Div holds nothing else.
--- @param div pandoc.Div
--- @return pandoc.Math|nil
local function only_display_math(div)
  if #div.content ~= 1 or div.content[1].t ~= 'Para' then
    return nil
  end
  local math = only_math(div.content[1].content)
  if math ~= nil and math.mathtype == 'DisplayMath' then
    return math
  end
  return nil
end

--- Tell whether an element carries nothing but its `alt` attribute: no identifier, no class, no other attribute.
--- @param element pandoc.Span|pandoc.Div
--- @return boolean
local function only_alt(element)
  if element.identifier ~= '' or #element.classes > 0 then
    return false
  end
  for key in pairs(element.attributes) do
    if key ~= 'alt' then
      return false
    end
  end
  return true
end

--- Remove the `alt` attribute in a format other than Typst.
--- The wrapper goes when it carries nothing else, and stays with its other attributes otherwise.
--- @param element pandoc.Span|pandoc.Div
--- @return pandoc.Inlines|pandoc.Blocks|pandoc.Span|pandoc.Div
local function drop_alt(element)
  if only_alt(element) then
    return element.content
  end
  element.attributes['alt'] = nil
  return element
end

--- Wrap maths in the equation call.
--- @param math pandoc.Math The maths
--- @param alt string The alt text
--- @return pandoc.Inlines
local function wrap(math, alt)
  return pandoc.Inlines({
    pandoc.RawInline('typst', M.open_call(math.mathtype == 'DisplayMath', alt)),
    math,
    pandoc.RawInline('typst', M.CLOSE_CALL),
  })
end

--- Add alt texts to the unlabelled maths of the document.
--- @param doc pandoc.Pandoc The document
--- @param config table The normalised `typst-extras` options
--- @return pandoc.Pandoc
function M.apply(doc, config)
  local is_typst = quarto.doc.is_format('typst')
  return doc:walk({
    Span = function(span)
      if not is_candidate(span) then
        return nil
      end
      local math = only_math(span.content)
      if math == nil then
        return nil
      end
      if not is_typst then
        return drop_alt(span)
      end
      return wrap(math, span.attributes['alt'])
    end,
    Div = function(div)
      if not is_candidate(div) then
        return nil
      end
      local math = only_display_math(div)
      if math == nil then
        return nil
      end
      if not is_typst then
        return drop_alt(div)
      end
      return pandoc.Para(wrap(math, div.attributes['alt']))
    end,
  })
end

return M
