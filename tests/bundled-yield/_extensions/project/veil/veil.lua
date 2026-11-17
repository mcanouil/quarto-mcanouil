return {
  {
    Pandoc = function(doc)
      quarto.doc.add_html_dependency({ name = 'veil', version = '9.9.9', scripts = { 'veil-stub.js' } })
      doc.blocks:insert(pandoc.Div({}, pandoc.Attr('project-veil')))
      return doc
    end,
  },
}
