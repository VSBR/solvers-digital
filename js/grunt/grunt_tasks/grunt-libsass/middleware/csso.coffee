csso = require 'csso'

exports.compile = (css, options)->
  css = csso.justDoIt(css)
  css
