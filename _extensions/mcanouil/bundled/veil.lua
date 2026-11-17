--- @module "bundled/veil"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Run the embedded veil filter `veil.lua`, unless the project has its own copy
--- @description The formats name this wrapper in place of the embedded extension,
--- so a project that keeps its own copy of veil runs that copy only.

local embedded = require(quarto.utils.resolve_path('../_vendor/quarto-lua-modules/embedded.lua'):gsub('%.lua$', ''))
local file = quarto.utils.resolve_path('../_extensions/mcanouil/veil/veil.lua')
return embedded.load('veil', file)
