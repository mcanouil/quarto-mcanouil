--- @module "bundled/codefrag"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Run the embedded codefrag filter `schema-filter.lua`, unless the project has its own copy
--- @description The formats name this wrapper in place of the embedded extension,
--- so a project that keeps its own copy of codefrag runs that copy only.

local embedded = require(quarto.utils.resolve_path('../_vendor/quarto-lua-modules/embedded.lua'):gsub('%.lua$', ''))
local file = quarto.utils.resolve_path('../_extensions/mcanouil/codefrag/schema-filter.lua')
return embedded.load('codefrag', file)
