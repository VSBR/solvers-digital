fs = require 'fs'
path = require 'path'

_type = (a, t)->
  args = Array::slice.call(arguments, 1)
  unless t = args.shift()
    return false
  to = typeof a
  if to == 'object'
    if t == 'object'
      return true
    if a == null and t == 'null'
      return true
    if t == 'arraylike' and typeof a.length == 'number'
      return true
    if a.constructor.name.toLowerCase() == t
      return true
  else if to == 'number'
    if t == 'number' or t == 'float'
      return true
    if t == 'ufloat' and a > 0
      return true
    if t == 'int' and a == ~~a
      return true
    if t == 'uint' and a == ~~a and a > 0
      return true
  else if to == t
    return true
  if args.length > 0
    args.unshift(a)
    return _type.apply(null, args)
  false


totime = (a)->
  if a == 'now'
    a = Date.now()
  else if a == 'today'
    d = new Date()
    d.setMilliseconds(0)
    d.setSeconds(0)
    d.setMinutes(0)
    d.setHours(0)
    a = d.getTime()
  else if typeof a == 'string'
    a = (new Date(a)).getTime()
  else if a instanceof Date
    a = a.getTime()
  a

_OP =
  'eq': (a,b)->
    if typeof b in ['string', 'number', 'boolean']
      return a == b
    if b instanceof RegExp
      return b.test(a)
    _OP.in(a,b)
  'in': (a,b)->
    if b instanceof Array
      return b.indexOf(a) != -1
    a in b
  'ne': (a,b)-> !_OP.eq(a, b)
  'nin': (a,b)-> !_OP.in(a, b)
  'lt': (a,b)-> a < b
  'lte': (a,b)-> a <= b
  'gt': (a,b)-> a > b
  'gte': (a,b)-> a >= b
  'range': (a,b)-> b[0] <= a and a <= b[1]
  'has': (a,b,p)-> Object::hasOwnProperty.call(p,a) == b
  'is': (a,b)-> !!(a and b)
  'type': (a,b)-> _type(a,b)
  'after': (a,b)->
    a = toTime(a)
    b = toTime(b)
    a < b
  'before': (a,b)->
    a = toTime(a)
    b = toTime(b)
    a > b
  'between': (a,b)->
    a = toTime(a)
    b0 = toTime(b[0])
    b1 = toTime(b[1])
    b0 <= a and a <= a1


where = (obj, props)->
  if typeof props.length == 'number' and props.length > 0
    for p in props
      if where(obj, p)
        return true
    return false
  for own name,val of props
    a = name.split(/__/)
    if a.length > 1
      name = a[0]
      op = a[1]
    else
      op = 'eq'
    if !_OP[op](obj[name], val, obj)
      return false
  true

query = (arr, props)->
  result = []
  for a in arr
    result.push a if where(a, props)
  result

getprop = (obj, props, alt)->
  props = props.replace(/^\[['"]?/, '')
  props = props.replace(/\[['"]?/, '.')
  props = props.replace(/['"]?\]/, '')
  props = props.split(/\./)
  for p in props
    if typeof obj != 'object'
      return alt
    if p.indexOf('*') > -1
      p = p.replace(/\*/g, '.*')
      p = p.replace /\{[^}]+\}/g, (m0)->
        '('+m0[1...-1].replace(/,/g,'|')+')'
      re = new RegExp('^'+p+'$')
      vals = []
      for own name, val of obj
        if re.test(name)
          vals.push val
      if vals.length == 0
        obj = undefined
      else
        obj = vals
    else
      obj = obj[p]
  obj

pluck = (arr, props)->
  result = []
  for a in arr
    val = getprop(a, props)
    if _type(val, 'array')
      for v in val when v
        result.push v
    else
      result.push val if val
  result

flatten = (arr)->
  result = []
  for a in arr
    if type(a, 'array')
      result = result.concat(a)
    else if type(a, 'arraylike')
      result = result.concat(Array::slice.call(a))
    else
      result.push a
  result

_json = (file, que, props)->
  key = file
  if key in _json.cache
    obj = _json.cache[key]
  else
    file = path.join(_json.path, file)
    if not fs.existsSync(file)
      console.log ('cant open json '+file).magenta
      return undefined
    text = fs.readFileSync(file)
    obj = JSON.parse(text)
    _json.cache[key] = obj
  arr = query(obj, que)
  arr = pluck(arr, props).sort()
  if _json.isReverse
    val = arr[arr.length-1]
  else
    val = arr[0]
  val


_json.path = '.'
_json.cache = {}
_json.isReverse = true

joinPath = (a, b)->
  a = a.split(path.sep)
  b = b.split(path.sep)
  tmp = a.concat(b)
  result = []
  for c in tmp
    if c == '..'
      result.pop()
    else if c == '.'
      null
    else
      result.push(c)
  result.join(path.sep)

dir = (filepath, lastsep=path.sep)->
  filepath.split(path.sep).slice(0,-1).join(path.sep)+lastsep

base = (filepath, whithext=false)->
  n = filepath.split(path.sep).slice(-1)[0]
  if whithext
    if n.indexOf('.') == -1
      return n
    else
      n.split(/\./).slice(0,-1).join('.')
  else
    n

ext = (filepath)->
  n = filepath.split(path.sep).slice(-1)[0]
  if n.indexOf('.') == -1
    return ''
  '.'+n.split(/\./).slice(-1)[0].toLowerCase()


find = (basePath, re=null)->
  ### 指定ディレクトリ以下の全ファイル列挙 ###
  list = []
  for p in fs.readdirSync(basePath)
    p = path.join basePath, p
    if (stat = fs.statSync(p)).isFile()
      if re
        console.log p
        if m = p.match(re)
          m = [].slice.call(m)
          list.push {p, m}
      else
        list.push p
    else if stat.isDirectory()
      list = list.concat find(p, re)
  list

extend = (obj1, obj2)->
  if arguments.length == 1
    obj2 = obj1
    obj1 = {}
  obj1
  for own prop,val of obj2 when not (prop of obj1)
    obj1[prop] = val
  obj1

exports.pluck = pluck
exports.query = query
exports.getprop = getprop
exports.json = _json
exports.type = _type
exports.joinPath = joinPath
exports.dir = dir
exports.base = base
exports.ext = ext
