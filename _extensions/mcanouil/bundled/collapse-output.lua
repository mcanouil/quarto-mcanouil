--- @module "bundled/collapse-output"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Run the embedded collapse-output filter `collapse-output.lua`, unless the project has its own copy
--- @description The formats name this wrapper in place of the embedded extension,
--- so a project that keeps its own copy of collapse-output runs that copy only.

local embedded = require(quarto.utils.resolve_path('../_vendor/quarto-lua-modules/embedded.lua'):gsub('%.lua$', ''))
local file = quarto.utils.resolve_path('../_extensions/mcanouil/collapse-output/collapse-output.lua')
return embedded.load('collapse-output', file)
