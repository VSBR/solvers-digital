
allcss = ''
allurl = ''

exports.compile = (css, options)->
  allcss += css
  if m = css.match(/url\([^\)]+\)/g)
    urlstr = ''
    # console.log options.dest
    for m0 in m
      m0 = m0.slice(4,-1)
      urlstr += m0
    allurl += urlstr
    console.log "#{allurl.length / allcss.length * 100}%"
  css

