--- @module "fail"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Raise errors in libraries, stop the render at the filter boundary
--- @description Quarto replaces the global `error` of a filter with a logger
--- that returns, so `error` neither raises nor stops a render. Libraries call
--- `raise`, which unwinds to the caller. A filter step wraps its entry point
--- with `guard`, which writes the message and exits non-zero.

local M = {}

--- Raise an error that the caller can catch with `pcall`.
--- @param message string Message to show
function M.raise(message)
  assert(false, message)
end

--- Stop the render with a message.
--- @param message string Message to show
function M.stop(message)
  io.stderr:write(message, '\n')
  os.exit(1)
end

--- Wrap a filter function so that an error stops the render with its message.
--- @param fn function Filter function
--- @return function Wrapped function
function M.guard(fn)
  return function(...)
    local ok, result = pcall(fn, ...)
    if not ok then
      M.stop(tostring(result))
    end
    return result
  end
end

return M
