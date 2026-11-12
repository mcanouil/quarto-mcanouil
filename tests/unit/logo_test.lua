local logo = require('logo')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

cases['logo-format-of-extension'] = function()
  assert_equal(logo.format_of('a/logo.SVG'), 'svg', 'svg')
  assert_equal(logo.format_of('logo.png'), 'png', 'png')
  assert_equal(logo.format_of('logo.jpeg'), 'jpg', 'jpeg')
  assert_equal(logo.format_of('logo.jpg'), 'jpg', 'jpg')
end

cases['logo-format-unknown-errors'] = function()
  local ok, err = pcall(logo.format_of, 'logo.bmp')
  assert_equal(ok, false, 'unknown format fails')
  assert_equal(tostring(err):find('logo.bmp', 1, true) ~= nil, true, 'message names the file')
end

cases['logo-bytes-literal'] = function()
  assert_equal(logo.bytes_literal('AB'), '(65, 66,)', 'two bytes')
end

cases['logo-locate-prefers-project-directory'] = function()
  assert_equal(logo.locate('a/b.svg', '/proj'), '/proj/a/b.svg', 'project path')
  assert_equal(logo.locate('/abs/b.svg', '/proj'), '/abs/b.svg', 'absolute path')
  assert_equal(logo.locate('b.svg', nil), 'b.svg', 'no project')
end

return cases
