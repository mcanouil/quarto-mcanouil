--- Extension Test - Staging the extension under test.
---
--- Quarto builds its extension registry while reading `_quarto.yml`, before
--- any `pre-render` script runs, so an extension copied in from inside a
--- render is not seen by that render. Staging therefore happens here, before
--- Quarto is invoked at all.
---
--- Staging is a copy, not a symlink. Measured against Quarto 99.9.9: a
--- symlinked extension inside a real `_extensions/` directory is silently not
--- resolved, and the render still exits 0 with only a warning. Symlinking the
--- whole `_extensions/` directory does work, but that shape is unavailable
--- here because the same directory must also hold the framework.

local util = require('util')

local M = {}

--- The owner directory generated copies are staged under.
---
--- `local` matches the convention the documentation sites already use. It
--- keeps a staged copy from colliding with an extension named after its
--- owner, and it says on the face of the path that the copy is generated.
M.STAGE_OWNER = 'local'

--- The project file names Quarto accepts for a directory.
M.PROJECT_FILES = { '_quarto.yml', '_quarto.yaml' }

--- Why staging cannot be resolved, when the tests directory is not a project.
---
--- Quarto resolves an extension from the project the document belongs to.
--- Without a project file the tests directory is not one, the staged copy is
--- never read, and every generated document reports a shortcode that is not
--- found. That reads as a broken extension when the harness is simply not set
--- up, so it is reported for what it is.
--- @param tests string tests directory
--- @return string|nil message
function M.missing_project(tests)
  for _, name in ipairs(M.PROJECT_FILES) do
    if util.exists(util.join(tests, name)) then
      return nil
    end
  end
  return string.format(
    'the tests directory has no `%s`, so the staged extension is not resolved; '
    .. 'add one that declares `project:` with `type: extension-test`',
    M.PROJECT_FILES[1])
end

--- The staging directory of a project.
--- @param dir string tests directory, or a project directory under it
--- @return string
local function target_of(dir)
  return util.join(dir, '_extensions', M.STAGE_OWNER)
end

--- Stage every extension a repository ships into the tests project, and into
--- each project directory under it.
---
--- A project directory under the tests directory resolves extensions only
--- inside itself, so a copy in the tests project is not seen by its render.
---
--- The staging directory is removed first. Copying onto an existing directory
--- nests the new copy inside the old one, which is the failure the
--- documentation sync scripts document.
--- @param root string repository root
--- @param tests string tests directory
--- @param projects string[]|nil absolute project directories under the tests directory
--- @return table staged {names, dir}
--- @return string|nil error
function M.stage(root, tests, projects)
  local source = util.join(root, '_extensions')
  local dir = target_of(tests)
  local targets = { dir }
  for _, project in ipairs(projects or {}) do
    targets[#targets + 1] = target_of(project)
  end

  for _, target in ipairs(targets) do
    util.remove_tree(target)
  end

  if not util.is_dir(source) then
    return { names = {}, dir = dir }, nil
  end

  local names = {}
  for _, name in ipairs(util.list_dir(source)) do
    local from = util.join(source, name)
    if util.is_dir(from) and util.exists(util.join(from, '_extension.yml')) then
      for _, target in ipairs(targets) do
        local ok, err = util.copy_tree(from, util.join(target, name))
        if not ok then
          return { names = names, dir = dir }, string.format('cannot stage `%s` into `%s`: %s',
            name, target, tostring(err))
        end
      end
      names[#names + 1] = name
    end
  end

  return { names = names, dir = dir }, nil
end

--- Remove the staging directories.
---
--- Only the generated owner directory is touched, never the framework's own
--- `tests/_extensions/<owner>/` beside it.
--- @param tests string tests directory
--- @param projects string[]|nil absolute project directories under the tests directory
function M.unstage(tests, projects)
  util.remove_tree(target_of(tests))
  -- A project's `_extensions/` was created by staging when it held nothing
  -- else, so it is removed again once empty. The removal is not recursive,
  -- so a directory that holds the project's own extensions stays.
  for _, project in ipairs(projects or {}) do
    util.remove_tree(target_of(project))
    pcall(pandoc.system.remove_directory, util.join(project, '_extensions'), false)
  end
end

--- Stage the extensions and check the project they are staged into.
---
--- Every failure unstages, so a part-copied extension is never left in the
--- tree for anything else that looks at it before the next run.
--- @param root string repository root
--- @param tests string tests directory
--- @param projects string[]|nil absolute project directories under the tests directory
--- @return table|nil staged {names, dir}, nil on failure
--- @return string|nil reason `staging-failed`, `nothing-to-stage` or `no-project-file`
--- @return string|nil message
function M.prepare(root, tests, projects)
  local staged, stage_err = M.stage(root, tests, projects)
  if stage_err then
    M.unstage(tests, projects)
    return nil, 'staging-failed', stage_err
  end
  if #staged.names == 0 then
    M.unstage(tests, projects)
    return nil, 'nothing-to-stage', 'the repository ships no extension to stage'
  end
  local missing = M.missing_project(tests)
  if missing then
    M.unstage(tests, projects)
    return nil, 'no-project-file', missing
  end
  return staged, nil, nil
end

return M
