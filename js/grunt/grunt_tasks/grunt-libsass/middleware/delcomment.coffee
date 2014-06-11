
exports.compile = (css, options)->
  cwd = options.cwd

  if cwd[cwd.length-1] != '/'
    cwd += '/'

  css = css.replace /\/\*[\s\S]*?\*\//g, (m0)->
    if m0[2...8] == ' line ' and m0.indexOf("\n") == -1
      return m0.replace(cwd, '')
    ""
  css = css.replace /[\n]{2,}/g, "\n"
  css








