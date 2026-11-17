--- @module "alt-text"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Warning for figures without alt text
--- @description Warns once for each image that has neither a `fig-alt` or `alt`
--- attribute nor a description. The warning names the figure by its identifier,
--- or by its source when it has none.

local M = {}

--- Answer whether an image has alt text.
--- @param image pandoc.Image Image
--- @return boolean True when `fig-alt`, `alt` or a description is set
function M.has_alt(image)
  for _, key in ipairs({ 'fig-alt', 'alt' }) do
    local value = image.attributes[key]
    if value ~= nil and value ~= '' then
      return true
    end
  end
  return #image.caption > 0
end

--- Answer the warning for an image with no alt text.
--- @param name string Identifier of the figure, or the source of the image
--- @return string Warning
function M.message(name)
  return string.format('mcanouil: figure "%s" has no alt text. Add fig-alt.', name)
end

--- @type table<string, boolean> Figures already reported.
local reported = {}

--- @type table<string, integer> Images of figures that were checked with the figure, by source.
local covered = {}

--- Warn about an image with no alt text, once for each figure.
--- @param image pandoc.Image Image
--- @param name string Identifier of the figure, or the source of the image
local function check(image, name)
  if M.has_alt(image) or reported[name] then
    return
  end
  reported[name] = true
  quarto.log.warning(M.message(name))
end

--- Check the images of a figure under the identifier of the figure.
--- @param figure table Pandoc figure, or Quarto float
--- @return nil
local function check_figure(figure)
  local content = figure.content
  if content == nil then
    return nil
  end
  local walkable = pandoc.utils.type(content) == 'Blocks' and pandoc.Div(content) or content
  walkable:walk({
    Image = function(image)
      covered[image.src] = (covered[image.src] or 0) + 1
      local name = figure.identifier ~= '' and figure.identifier or image.src
      local float_alt = figure.attributes and figure.attributes['fig-alt']
      if float_alt == nil or float_alt == '' then
        check(image, name)
      end
    end,
  })
end

--- Check an image that is not part of a figure.
--- @param image pandoc.Image Image
--- @return nil
local function check_image(image)
  if (covered[image.src] or 0) > 0 then
    covered[image.src] = covered[image.src] - 1
    return
  end
  check(image, image.identifier ~= '' and image.identifier or image.src)
end

--- @type table Filter step of the entry filter.
M.filter = { traverse = 'topdown', Figure = check_figure, FloatRefTarget = check_figure, Image = check_image }

return M
