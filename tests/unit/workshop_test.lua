local workshop = require('workshop')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

-- Labels read the document language from Quarto, which the unit runner does
-- not have: run a function with an empty language table, so labels are English.
local function in_english(fn)
  local saved = quarto
  quarto = { doc = { language = {} } }
  local ok, err = pcall(fn)
  quarto = saved
  if not ok then
    error(err, 0)
  end
end

local function meta(values)
  return { extensions = { mcanouil = values } }
end

cases['workshop-session-text'] = function()
  in_english(function()
    assert_equal(workshop.session_text(meta({ session = { number = '2', total = '7' } })), 'Session 2 of 7', 'number and total')
    assert_equal(workshop.session_text(meta({ session = { number = '2' } })), 'Session 2', 'number only')
    assert_equal(workshop.session_text(meta({})), nil, 'no session')
  end)
end

cases['workshop-exercise-label'] = function()
  in_english(function()
    assert_equal(workshop.exercise_label(1, '2', '15 min', 'pairs'), 'Exercise 2.1 · 15 min · pairs', 'all parts')
    assert_equal(workshop.exercise_label(3, nil, nil, nil), 'Exercise 3', 'number only')
    assert_equal(workshop.exercise_label(1, '2', nil, 'solo'), 'Exercise 2.1 · solo', 'no duration')
  end)
end

cases['workshop-solutions-mode'] = function()
  assert_equal(workshop.solutions_mode(meta({})), 'end', 'default')
  assert_equal(workshop.solutions_mode(meta({ solutions = 'inline' })), 'inline', 'inline')
  local mode, message = workshop.solutions_mode(meta({ solutions = 'appendix' }))
  assert_equal(mode, nil, 'unknown mode')
  assert_equal(message, 'mcanouil: unknown solutions "appendix"; use end, inline, hide.', 'message')
end

cases['workshop-solution-label'] = function()
  in_english(function()
    assert_equal(workshop.solution_label(nil), 'Solution', 'plain')
    assert_equal(workshop.solution_label('Worked answer'), 'Solution · Worked answer', 'name')
    assert_equal(workshop.solution_label('Worked answer', '2.1'), 'Solution 2.1 · Worked answer', 'number and name')
  end)
end

return cases
