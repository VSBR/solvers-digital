fs = require 'fs'

reIndent  = /^([\ \t]*)/

class CSON
  cls = this

  @headString = '# このファイルはconflictしてもgruntで自動修復されます手動で解決しないで下さい\n'

  @load = (file, alt)->
    if not fs.existsSync(file)
      return alt
    text = fs.readFileSync(file, 'utf8')
    cls.parse(text)


  @parse = (lines)->
    if typeof lines == 'string'
      lines = lines.split(/\n/)
    cls.parseObj(lines)

  @parseObj = (lines, startIndex=0, beforeIndent=-1)->
    if lines.length == 0
      return null
    result = {}
    i = startIndex - 1
    while ++i < lines.length
      ln = lines[i]
      if /^<<<<<<</.test(ln)
        # conflictしてる。HEADは無視するよ
        for j in [i+1...lines.length]
          ln = lines[j]
          if /^=======/.test(ln)
            i = j
            break
        continue
      if /^>>>>>>>/.test(ln)
        # 読み飛ばす
        continue
      if /^#/.test(ln)
        # 読み飛ばす
        continue
      indent = ln.match(reIndent)[1].length
      if indent == ln.length
        continue
      if indent <= beforeIndent
        break
      ln = ln[indent...]
      key = cls.parseStr(ln)
      splitter = cls.parseStr(cls.right)
      if splitter != ':'
        throw new Error 'cant find objsplitter key:'+key+'  splitter:['+splitter+']'
      r = cls.right.trim()
      if r
        value = cls.parseValue(cls.right)
        if cls.syntax
          if cls.syntax == 'array_start'
            value = cls.parseArr(lines, i+1)
            i = cls.endIndex
          else
            throw new Error 'unknown sytax:'+ln
        r = cls.right.replace(/#.*$/, '').trim()
        if r
          throw new Error 'unknown sytax:'+ln
      else
        # keyname : ### 空白 ###
        value = cls.parseObj(lines, i+1, indent)
        i = cls.endIndex
      result[key] = value
    cls.endIndex = i-1
    result

  @parseValue = (str)->
    value = cls.parseStr(str)
    cls.syntax = ''
    if cls.quote
      return value
    if value == '{}'
      return {}
    else if value == '[]'
      return []
    else if value == 'false'
      return false
    else if value == 'true'
      return true
    else if value == 'undefined'
      return undefined
    else if /^\-?[0-9\.]+$/.test(value)
      return +value
    else if value == '['
      cls.syntax = 'array_start'
      return value
    else if value == ']'
      cls.syntax = 'array_end'
      return value
    cls.syntax = 'indentifer'
    return value





  @parseStr = (str)->
    esc = false
    quote = false
    result = ''
    for c,i in str
      if esc and c == 't'
        result += "\t"
        esc = false
        continue
      if esc and c == 'n'
        result += "\n"
        esc = false
        continue
      if esc and c == 'r'
        result += "\r"
        esc = false
        continue
      if esc and c == 'r'
        result += "\r"
        esc = false
        continue
      if esc
        # quote含む
        result += c
        esc = false
        continue
      if c == '\\'
        esc = true
        continue
      if not quote and c == ' ' and not result
        continue
      if not quote and c in [':',','] and not result
        result += c
        i += 1
        break
      if not quote and c in [' ','\t','\n','\r',':','['] and result
        break
      if not quote and c in ['"',"'"]
        result = '' # u"hoge", b'hoge' などのprequoteを削除
        if str[i+1] == str[i+2] == c
          quote = c+c+c
        else
          quote = c
        continue
      if quote and c == quote[0]
        if quote.length == 3
          if str[i...i+3] == quote
            i += 3
            break
          result += c
          continue
        else
          i += 1
          break
      if not result and c == ' '
        continue
      result += c
    cls.quote = quote
    cls.right = str[i...]
    result

  _stringify = (obj, indent)->
    result = ''
    if typeof obj == 'string'
      if /^[\-_a-zA-Z0-9$]+$/.test(obj)
        return obj
      else
        obj = obj.replace(/\\/g, '\\\\')
        obj = obj.replace(/'/g, "\\'")
        obj = obj.replace(/\t/g, "\\t")
        obj = obj.replace(/\n/g, "\\n")
        obj = obj.replace(/\r/g, "\\r")
        return "'#{obj}'"
    else if typeof obj == 'number'
      return obj.toString()
    else if typeof obj == 'boolean'
      return obj.toString()
    else if obj == null
      return 'null'
    else if obj == undefined
      return 'undefined'
    else if obj instanceof Array
      result += ' [\n'
      ni = indent+'  '
      for a in obj
        result += ni + _stringify(a,ni) + '\n'
      result += indent+']\n'
    else if typeof obj == 'object'
      if Object.keys(obj).length == 0
        result = ' {}\n'
      else
        result += '\n'
        ni = indent+'  '
        for own k,v of obj
          k = _stringify(k, '')
          if v and typeof v == 'object'
            result += ni + k + ':' + _stringify(v,ni)
          else
            result += ni + k + ': ' + _stringify(v,ni) + '\n'
    else
      throw new Error 'unknow obj:'+obj
    result

  @stringify = (obj)->
    if obj and typeof obj == 'object'
      result = ''
      ni = ''
      for own k,v of obj
        k = _stringify(k, '')
        if v and typeof v == 'object'
          result += k + ':' + _stringify(v,ni)
        else
          result += k + ': ' + _stringify(v,ni) + '\n'
      return result
    else
      return _stringify(obj, '')

  @save = (file, obj)->
    str = cls.stringify(obj)
    str = cls.headString + str
    fs.writeFileSync file, str, 'utf8'

module.exports = CSON