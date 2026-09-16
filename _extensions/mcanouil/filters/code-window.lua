--- @module "code-window-main"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Entry point for the code-window extension.
--- Loads all submodules, wires dependencies, and assembles the filter list.

local EXTENSION_NAME = 'mcanouil'
local log = require(quarto.utils.resolve_path('../_vendor/quarto-lua-modules/logging.lua'):gsub('%.lua$', ''))

-- ============================================================================
-- LOAD SUBMODULES
-- ============================================================================

local str = require(
  quarto.utils.resolve_path('../_vendor/quarto-lua-modules/string.lua'):gsub('%.lua$', ''))

local meta_mod = require(
  quarto.utils.resolve_path('../_vendor/quarto-lua-modules/metadata.lua'):gsub('%.lua$', ''))

local pdoc = require(
  quarto.utils.resolve_path('../_vendor/quarto-lua-modules/pandoc-helpers.lua'):gsub('%.lua$', ''))

local html_mod = require(
  quarto.utils.resolve_path('../_vendor/quarto-lua-modules/html.lua'):gsub('%.lua$', ''))

local language = require(
  quarto.utils.resolve_path('../_modules/language.lua'):gsub('%.lua$', ''))

local code_annotations = require(
  quarto.utils.resolve_path('../_modules/hotfix/code-annotations.lua'):gsub('%.lua$', ''))

local code_window = require(
  quarto.utils.resolve_path('../_modules/code-window.lua'):gsub('%.lua$', ''))

local schema = require(
  quarto.utils.resolve_path('../_vendor/quarto-wizard/schema.lua'):gsub('%.lua$', ''))

local schema_check = require(
  quarto.utils.resolve_path('../_vendor/quarto-lua-modules/schema-check.lua'):gsub('%.lua$', ''))

-- Inject all dependencies into the code-window module
code_window.set_dependencies({
  str = str,
  log = log,
  meta_mod = meta_mod,
  pdoc = pdoc,
  html_mod = html_mod,
  code_annotations = code_annotations,
})

-- ============================================================================
-- SCHEMA CHECK
-- ============================================================================

--- The schema check for the `CodeBlock` attribute group, built once for the
--- render. No checker instance existed anywhere in this file's own
--- processing, unlike `filters/components.lua`, so this is the first one
--- built here, not a second one layered on an existing instance.
---
--- The schema path is given because the check module resolves it against the
--- directory of the entry point that is running, and this file sits one
--- directory below the schema.
local checker = schema_check.new(schema, EXTENSION_NAME, '../_schema.yml')

--- Check a code block's `code-window-*` attributes against the schema, and
--- return the block unchanged.
---
--- This is a validation-only pass: `code-window-enabled` and
--- `code-window-style` are read again, unchanged, by `code_window.CodeBlock`
--- (HTML) and by the Typst block walk in `code_window.Pandoc`, exactly as
--- before this task. `code-window-no-auto-filename` is read there the same
--- way too, and deliberately not routed through the schema-resolved value:
--- both read sites test the raw attribute for Lua truthiness rather than
--- comparing it against the string "true", so the string "false" is already
--- truthy and already suppresses the auto filename exactly as "true" does,
--- against the schema's own declared default of false. That is a
--- pre-existing defect, independent of this check, and this task's own
--- global constraints direct that a defect a task's change merely reveals is
--- reported and preserved, not fixed under cover of a schema check.
---
--- Run first in the filter list, before `language.CodeBlock` can inject its
--- own `code-window-no-auto-filename` value for a block with no recognised
--- language, so only what the document itself wrote is ever checked.
--- @param block pandoc.CodeBlock Code block element
--- @return pandoc.CodeBlock block Unchanged
local function check_code_window_attributes(block)
  checker:attributes(block.attributes, 'CodeBlock')
  return block
end

-- ============================================================================
-- SKYLIGHTING HOT-FIX
-- ============================================================================

--- Load optional skylighting hot-fix module from sibling file.
--- @return table Module table with .filters and .set_wrapper, or empty table
local function load_skylighting_hotfix_module()
  local ok, result = pcall(require,
    quarto.utils.resolve_path('../_modules/hotfix/skylighting-typst-fix.lua'):gsub('%.lua$', ''))
  if not ok then
    log.log_warning(EXTENSION_NAME,
      'Failed to load optional skylighting hot-fix: ' .. tostring(result))
    return {}
  end
  if type(result) ~= 'table' then
    log.log_warning(EXTENSION_NAME,
      'Skylighting hot-fix did not return a module table.')
    return {}
  end
  return result
end

-- ============================================================================
-- FILTER ASSEMBLY
-- ============================================================================

local filters = {
  { CodeBlock = check_code_window_attributes },
  { CodeBlock = language.CodeBlock },
  { Meta = code_window.Meta },
  { Pandoc = code_window.Pandoc },
  { CodeBlock = code_window.CodeBlock },
}

local skylighting_mod = load_skylighting_hotfix_module()

for _, subfilter in ipairs(skylighting_mod.filters or {}) do
  local wrapped = {}
  for element_type, handler in pairs(subfilter) do
    wrapped[element_type] = function(...)
      local cfg = code_window.CONFIG()
      if not cfg or not cfg.hotfix_skylighting then
        return nil
      end
      if skylighting_mod.set_wrapper then
        skylighting_mod.set_wrapper(cfg.typst_wrapper)
      end
      return handler(...)
    end
  end
  table.insert(filters, wrapped)
end

return filters
