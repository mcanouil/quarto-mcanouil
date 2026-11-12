--- @module "fail"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @brief Stop the render with a message
--- @description Quarto replaces the global `error` of a filter with a logger
--- that returns, so `error` never stops a render. `stop` writes the message to
--- stderr and exits non-zero. The unit tests set `raising` to get a Lua error
--- they can catch.

local M = {}

--- @type boolean When true, `stop` raises a Lua error instead of exiting.
M.raising = false

--- Stop the render.
--- @param message string Message to show
function M.stop(message)
  if M.raising then
    error(message, 0)
  end
  io.stderr:write(message, '\n')
  os.exit(1)
end

return M
