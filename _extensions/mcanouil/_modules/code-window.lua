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

--- @module code-window
--- @author Mickaël Canouil
--- @version 1.0.0
--- @brief Self-contained code-window filter for macOS-style code blocks
--- @description Processes CodeBlock elements with filename attribute.
--- Can be used independently or integrated into larger filter systems.

local M = {}

-- Extension namespace section name
local SECTION_NAME = 'code-window'

-- ============================================================================
-- DEFAULT CONFIGURATION
-- ============================================================================

--- @class CodeWindowConfig
--- @field enabled boolean Whether code-window styling is enabled
--- @field auto_filename boolean Whether to auto-generate filename from language
--- @field typst_wrapper string Typst wrapper function name

--- Default configuration values
M.DEFAULT_CONFIG = {
  enabled = false,
  auto_filename = false,
  typst_wrapper = 'mcanouil-code-window',
}

-- ============================================================================
-- CONFIGURATION LOADING
-- ============================================================================

--- Load configuration from document metadata.
--- Reads from extensions.mcanouil.code-window namespace.
--- @param meta pandoc.Meta Document metadata
--- @return CodeWindowConfig Configuration table
function M.get_config(meta)
  local config = {
    enabled = M.DEFAULT_CONFIG.enabled,
    auto_filename = M.DEFAULT_CONFIG.auto_filename,
    typst_wrapper = M.DEFAULT_CONFIG.typst_wrapper,
  }

  local ext_config = meta.extensions and meta.extensions.mcanouil
      and meta.extensions.mcanouil[SECTION_NAME]
  if not ext_config then
    return config
  end

  if ext_config.enabled ~= nil then
    config.enabled = pandoc.utils.stringify(ext_config.enabled) == 'true'
  end
  if ext_config['auto-filename'] ~= nil then
    config.auto_filename = pandoc.utils.stringify(ext_config['auto-filename']) == 'true'
  end
  if ext_config.wrapper ~= nil then
    config.typst_wrapper = pandoc.utils.stringify(ext_config.wrapper)
  end

  return config
end

-- ============================================================================
-- FILENAME RESOLUTION
-- ============================================================================

--- Get display filename for a code block.
--- Returns explicit filename if provided, or language if auto_filename is enabled.
--- @param block pandoc.CodeBlock Code block element
--- @param auto_filename boolean Whether to auto-generate from language
--- @return string|nil Filename to display, or nil if none
function M.get_filename(block, auto_filename)
  local filename = block.attributes['filename']

  -- Use explicit filename if provided
  if filename and filename ~= '' then
    return filename
  end

  -- Auto-generate from language if enabled
  if auto_filename and block.classes and #block.classes > 0 then
    return block.classes[1]
  end

  return nil
end

-- ============================================================================
-- FORMAT-SPECIFIC PROCESSORS
-- ============================================================================

--- Process CodeBlock for Typst format.
--- Wraps code block with Typst wrapper function that sets state for show rules.
--- Passes 'auto: true' when filename is auto-generated for smallcaps styling.
--- @param block pandoc.CodeBlock Code block element
--- @param config CodeWindowConfig Configuration from get_config()
--- @return pandoc.RawBlock|pandoc.CodeBlock Transformed or original block
function M.process_typst(block, config)
  local explicit_filename = block.attributes['filename']
  local filename = M.get_filename(block, config.auto_filename)

  if not filename then
    return block
  end

  -- Determine if filename is auto-generated (no explicit filename, auto enabled)
  local is_auto = (not explicit_filename or explicit_filename == '') and config.auto_filename

  local lang = ''
  if block.classes and #block.classes > 0 then
    lang = block.classes[1]
  end

  local code_content = block.text
  local typst_code = string.format(
    '#%s(filename: "%s", is-auto: %s)[```%s\n%s\n```]',
    config.typst_wrapper,
    filename:gsub('"', '\\"'),
    is_auto and 'true' or 'false',
    lang,
    code_content
  )

  return pandoc.RawBlock('typst', typst_code)
end

--- Process CodeBlock for HTML/Reveal.js formats.
--- For auto-generated filenames: creates wrapper structure with 'code-window-auto' class.
--- For explicit filenames: let Quarto handle it (CSS will style it).
--- @param block pandoc.CodeBlock Code block element
--- @param config CodeWindowConfig Configuration from get_config()
--- @return pandoc.Div|pandoc.CodeBlock Wrapped block or original
function M.process_html(block, config)
  local explicit_filename = block.attributes['filename']

  -- If block already has explicit filename, let Quarto handle it
  -- Our CSS will style it correctly
  if explicit_filename and explicit_filename ~= '' then
    return block
  end

  -- Check if we should auto-generate filename from language
  if not config.auto_filename then
    return block
  end

  -- Get language as filename
  if not block.classes or #block.classes == 0 then
    return block
  end

  local filename = block.classes[1]

  -- Create Quarto-compatible .code-with-filename structure with auto marker:
  -- <div class="code-with-filename code-window-auto">
  --   <div class="code-with-filename-file">
  --     <pre><strong>filename</strong></pre>
  --   </div>
  --   [code block]
  -- </div>
  -- The 'code-window-auto' class signals CSS to apply small-caps styling
  local filename_header = pandoc.RawBlock(
    'html',
    string.format(
      '<div class="code-with-filename-file"><pre><strong>%s</strong></pre></div>',
      filename
    )
  )

  return pandoc.Div(
    { filename_header, block },
    pandoc.Attr('', { 'code-with-filename', 'code-window-auto' })
  )
end

-- ============================================================================
-- FORMAT-AGNOSTIC ENTRY POINT
-- ============================================================================

--- Process CodeBlock element for any format.
--- Dispatches to format-specific processor based on current format.
--- @param block pandoc.CodeBlock Code block element
--- @param format string Current format ('typst', 'html', 'revealjs')
--- @param config CodeWindowConfig Configuration from get_config()
--- @return pandoc.RawBlock|pandoc.CodeBlock Transformed or original block
function M.process(block, format, config)
  if not config.enabled then
    return block
  end

  if format == 'typst' then
    return M.process_typst(block, config)
  end

  if format == 'html' or format == 'revealjs' then
    return M.process_html(block, config)
  end

  return block
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return M
