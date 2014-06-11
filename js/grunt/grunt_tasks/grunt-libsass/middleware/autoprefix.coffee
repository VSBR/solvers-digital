PREFIX = '-webkit-'
PROPATIES = [
  'appearance'
  'animation'
  'animation-name'
  'animation-duration'
  'animation-timing-function'
  'animation-iteration-count'
  'animation-direction'
  'animation-play-state'
  'animation-delay'
  'animation-fill-mode'
  'backface-visibility'
  'background-clip'
  'box-orient'
  'box-align'
  'box-pack'
  'box-sizing'
  'box-flex'
  'box-lines'
  'border-image'
  'filter'
  'line-clamp'
  'margin-before'
  'margin-after'
  'margin-start'
  'margin-end'
  'mask'
  'mask-box-image'
  'mask-size'
  'mask-image'
  'mask-position'
  'mask-repeat'
  'overflow-scrolling'
  'text-stroke'
  'text-fill-color'
  'tap-highlight-color'
  'touch-callout'
  'transform'
  'transform-style'
  'transform-origin'
  'transform-origin-x'
  'transition'
  'transition-property'
  'transition-duration'
  'transition-timing-function'
  'transition-delay'
  'user-select'
]
VALUES = [
  'box'
  'transform'
]

DIRECTIVES = [
  'keyframes'
]

re_props = null
re_values = null
re_directives = null

exports.compile = (css, options)->

  if not re_props
    pat = "([\\t {;])(#{PROPATIES.join('|')})(\\s*:)"
    re_props = new RegExp(pat, 'g')

  if not re_values
    pat = "(:\\s*)(#{VALUES.join('|')})(\\s*[;}])"
    re_values = new RegExp(pat, 'g')

  if not re_directives
    pat = "@(#{DIRECTIVES.join('|')})([\\ {\\(])"
    re_directives = new RegExp(pat, 'g')

  css = css.replace(re_props, "$1#{PREFIX}$2$3")
  css = css.replace(re_values, "$1#{PREFIX}$2$3")
  css = css.replace(re_directives, "@#{PREFIX}$1$2")

  css








