--- @module "mcanouil-pre"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Opening filter of the mcanouil extension
--- @description Returns the list of filter steps that run before Quarto parses
--- the document, so they see the blocks as the author wrote them.

--- @type string Directory of this file, searched for the sibling modules.
local LUA_DIR = debug.getinfo(1, 'S').source:match('^@(.*)[/\\][^/\\]+$')

package.path = LUA_DIR .. '/?.lua;' .. package.path

local workshop = require('workshop')

--- @type table[] The filter steps, run in order.
local STEPS = {
  workshop.pre_filters[1],
  workshop.pre_filters[2],
}

return STEPS
