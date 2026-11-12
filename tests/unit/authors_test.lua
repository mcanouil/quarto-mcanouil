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

local ROLES = [[
authors:
  - name:
      literal: Ana Author
    roles:
      - { role: conceptualization, degree-of-contribution: lead, vocab-term: conceptualization }
      - { role: Writing, degree-of-contribution: Equal }
      - supervision
      - { role: writing, vocab-term: "writing \u2013 original draft" }
  - name:
      literal: Ben Writer
]]

cases['authors-collect-roles'] = function()
  local people = authors.collect(meta_of(ROLES)).authors
  assert_equal(#people[1].roles, 4, 'role count')
  assert_equal(people[1].roles[1].role, 'conceptualization', 'role name')
  assert_equal(people[1].roles[1].degree, 'lead', 'degree')
  assert_equal(people[1].roles[2].degree, 'equal', 'degree is lower case')
  assert_equal(people[1].roles[3].degree, '', 'no degree')
  assert_equal(people[1].roles[4].role, 'writing, original draft', 'the dash of a CRediT term becomes a comma')
  assert_equal(#people[2].roles, 0, 'no roles')
end

cases['authors-typst-roles'] = function()
  local literal = authors.typst(authors.collect(meta_of(ROLES)))
  assert_equal(literal:find('roles: ((role: "conceptualization", degree: "lead"),', 1, true) ~= nil, true, 'roles array')
  assert_equal(literal:find('roles: ())', 1, true) ~= nil, true, 'empty roles array')
end

local CREDIT = [[
authors:
  - name:
      literal: Ana Author
    roles:
      - { role: conceptualization, degree-of-contribution: lead }
      - { role: writing, degree-of-contribution: equal }
  - name:
      literal: Ben Writer
    roles:
      - { role: writing, degree-of-contribution: supporting }
      - supervision
]]

local TEXT = { ['mcanouil-credit-lead'] = 'Lead', ['mcanouil-credit-equal'] = 'Equal',
  ['mcanouil-credit-supporting'] = 'Supporting', ['mcanouil-credit-contributed'] = 'Contributed' }

local function label(key) return TEXT[key] end

cases['credit-matrix-rows-and-marks'] = function()
  local matrix = authors.credit_matrix(authors.collect(meta_of(CREDIT)), label)
  assert_equal(table.concat(matrix.columns, '|'), 'AA|BW', 'initials of the authors')
  assert_equal(#matrix.rows, 3, 'each role once, in order of first appearance')
  assert_equal(matrix.rows[1].role, 'Conceptualization', 'role is capitalised')
  assert_equal(table.concat(matrix.rows[1].marks, '|'), 'L|', 'lead and no role')
  assert_equal(table.concat(matrix.rows[2].marks, '|'), 'E|S', 'equal and supporting')
  assert_equal(table.concat(matrix.rows[3].marks, '|'), '|\u{2022}', 'a role with no degree')
end

cases['credit-matrix-legend'] = function()
  local matrix = authors.credit_matrix(authors.collect(meta_of(CREDIT)), label)
  assert_equal(matrix.legend, 'L Lead \u{b7} E Equal \u{b7} S Supporting \u{b7} \u{2022} Contributed', 'legend of the marks in use')
end

cases['credit-matrix-none'] = function()
  assert_equal(authors.credit_matrix(authors.collect(meta_of(NORMALISED)), label), nil, 'no roles, no table')
end

return cases
