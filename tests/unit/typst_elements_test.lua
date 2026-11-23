local typst_elements = require('typst-elements')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

cases['typst-elements-math-alt-one-line'] = function()
  assert_equal(typst_elements.math_alt('E = mc^2'), 'E = mc^2', 'inline maths')
  assert_equal(typst_elements.math_alt('\n  \\int_0^1 x^2 \\, dx\n  = \\frac{1}{3}\n'), '\\int_0^1 x^2 \\, dx = \\frac{1}{3}', 'display maths on one line')
end

cases['typst-elements-callout-marker'] = function()
  assert_equal(
    typst_elements.callout_marker('warning', 'simple', true),
    '#metadata((mc-callout: "warning", appearance: "simple", titled: true))',
    'marker of a titled simple warning'
  )
  assert_equal(
    typst_elements.callout_marker('tip', nil, false),
    '#metadata((mc-callout: "tip", appearance: "default", titled: false))',
    'marker with the default appearance'
  )
end

cases['typst-elements-task-marks'] = function()
  assert_equal(typst_elements.TASK_MARKS['\u{2610}'], false, 'open task')
  assert_equal(typst_elements.TASK_MARKS['\u{2612}'], true, 'done task')
end

return cases
