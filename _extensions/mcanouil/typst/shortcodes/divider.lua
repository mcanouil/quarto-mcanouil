--[[
# MIT License
#
# Copyright (c) 2026 Mickaël Canouil
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
]]

--- @module divider
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Divider shortcode for Typst format
--- @description Provides {{< divider >}} shortcode for rendering decorative dividers.
--- This shortcode generates calls to #mcanouil-divider defined in typst-show.typ.

--- Load Typst utilities module
local typst_utils = require(
  quarto.utils.resolve_path('../_modules/typst-utils.lua'):gsub('%.lua$', '')
)

-- ============================================================================
-- SHORTCODE HANDLER
-- ============================================================================

--- @type table<string, function> Shortcode handlers
return {
  ['divider'] = typst_utils.create_shortcode_handler('mcanouil-divider')
}
