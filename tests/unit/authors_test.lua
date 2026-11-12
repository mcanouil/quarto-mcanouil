local authors = require('authors')

local cases = {}

local function assert_equal(actual, expected, what)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', what, tostring(expected), tostring(actual)), 2)
  end
end

local function meta_of(yaml)
  return pandoc.read('---\n' .. yaml .. '\n---\n', 'markdown').meta
end

local NORMALISED = [[
authors:
  - name:
      literal: Mickaël Canouil
    degrees: [Ph.D., M.Sc.]
    orcid: 0000-0002-3396-4549
    email: contact@example.org
    attributes: { corresponding: true, equal-contributor: true }
    affiliations: [{ ref: inserm }, { ref: imperial }]
  - name:
      literal: Gus Elder
    attributes: { deceased: true }
    affiliations: [{ ref: imperial }]
affiliations:
  - id: inserm
    number: 1
    name: Inserm U1283
    department: Department of Genomics
    city: Lille
    country: France
  - id: imperial
    number: 2
    name: Imperial College London
    country: UK
]]

cases['authors-collect-fields'] = function()
  local people = authors.collect(meta_of(NORMALISED)).authors
  assert_equal(#people, 2, 'author count')
  assert_equal(people[1].name, 'Mickaël Canouil', 'name')
  assert_equal(table.concat(people[1].degrees, '|'), 'Ph.D.|M.Sc.', 'degrees')
  assert_equal(table.concat(people[1].affiliations, ','), '1,2', 'affiliation numbers')
  assert_equal(people[1].orcid, '0000-0002-3396-4549', 'orcid')
  assert_equal(people[1].corresponding, true, 'corresponding')
  assert_equal(people[1].equal, true, 'equal contribution')
  assert_equal(people[1].deceased, false, 'deceased')
  assert_equal(people[2].deceased, true, 'deceased author')
  assert_equal(people[2].corresponding, false, 'not corresponding')
end

cases['authors-collect-affiliation-line'] = function()
  local result = authors.collect(meta_of(NORMALISED))
  assert_equal(result.affiliations[1], 'Inserm U1283, Department of Genomics, Lille, France', 'full line')
  assert_equal(result.affiliations[2], 'Imperial College London, UK', 'short line')
end

cases['authors-collect-email-of-corresponding'] = function()
  assert_equal(authors.collect(meta_of(NORMALISED)).email, 'contact@example.org', 'corresponding email')
end

cases['authors-collect-none'] = function()
  assert_equal(authors.collect(meta_of('title: x')), nil, 'no authors')
end

cases['authors-typst-literal-escapes'] = function()
  local literal = authors.typst({
    authors = { { name = 'A "B" \\ C', degrees = {}, affiliations = { 1 }, orcid = '', corresponding = false, equal = false, deceased = false } },
    affiliations = { 'X' },
    email = '',
  })
  assert_equal(literal:find('name: "A \\"B\\" \\\\ C"', 1, true) ~= nil, true, 'escaped name')
  assert_equal(literal:find('affiliations: (1,)', 1, true) ~= nil, true, 'one element array keeps its comma')
end

return cases
