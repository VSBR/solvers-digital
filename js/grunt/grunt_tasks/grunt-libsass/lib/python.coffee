fs = require 'fs'

reIndent  = /^([\ \t]*)/

class Python
  # python source 簡易パーサ
  cls = this

  _tok = (str)->
    esc = false
    quote = false
    result = ''
    i = -1
    while ++i < str.length
      c = str[i]
      if esc
        if c == 't'
          result += "\t"
        else if c == 'n'
          result += "\n"
        else if c == 'r'
          result += "\r"
        else if c == 'r'
          result += "\r"
        else
          # quote含む
          result += c
        esc = false
        continue
      if c == '\\'
        esc = true
        continue
      if not quote
        if c in ['"',"'"]
          result = '' # u"hoge", b'hoge' などのprequoteを削除
          if str[i+1] == str[i+2] == c
            quote = c+c+c
            i += 2
          else
            quote = c
          continue
        if not result
          if c == '#'
            quote = '#'
            result += '#'
            continue
          if c == ' '
            continue
          else if /[^a-zA-Z0-9_]/.test(c)
            result += c
            i += 1
            break
        else
          if /[^a-zA-Z0-9_]/.test(c)
            break
        result += c
        continue
      if quote
        if quote == '#'
          if c == '\n'
            result += c
            break
          else
            result += c
            continue
        if c == quote[0]
          if quote.length == 3
            if str[i...i+3] == quote
              i += 3
              break
            result += c
            continue
          else
            i += 1
            break
        result += c
        continue

    cls.quote = quote
    cls.right = str[i...]
    result

  _idt = (str)->
    reIndent.match(str)[0]

  _token = (src)->
    result = []
    nl = true
    while src
      if nl
        s = src.match(reIndent)[0]
        result.push {s,idt:1}
        nl = false
      s = _tok(src)
      if cls.quote == '#'
        undefined
      else if cls.quote
        result.push {s,lit:1}
      else if /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(s)
        result.push {s,id:1}
      else if /^\-?[0-9\.]+$/.test(s) and s != '.'
        result.push {s:+s,lit:1}
      else
        if s == '\n'
          nl = true
          result.push {s,nl:1}
        else
          result.push {s,op:1}
      src = cls.right
    #
    tmp = []
    i = -1
    while ++i < result.length
      o1 = tmp[tmp.length-1]
      o2 = result[i]
      if o1 and o1.idt and o2.nl
        tmp.pop()
      else
        tmp.push o2
    result = tmp
    #
    tmp = []
    i = -1
    while ++i < result.length
      o1 = tmp[tmp.length-2]
      o2 = tmp[tmp.length-1]
      o3 = result[i]
      if o1 and o1.id and o2.op and o2.s == '.' and o3.id
        tmp.pop()
        tmp.pop()
        s = o1.s+'.'+o3.s
        tmp.push {s:s,id:1}
      else
        tmp.push o3
    result = tmp
    result

  _parseBraket = (tokens, bra='')->
    tokens = tokens.slice(0)
    brakets =
      '(':')'
      '{':'}'
      '[':']'
    ket = brakets[bra]
    tree = []
    i = -1
    ls = []
    stack = []
    while ++i < tokens.length
      t = tokens[i]
      if t.op and t.s of brakets
        _tokens = _parseBraket(tokens[i+1...], t.s)
        tokens = tokens[...i].concat(_tokens)
        t = tokens[i]
      if bra
        if t.nl or t.idt
          tokens.splice(i,1)
          i--
          continue
        else if t.op and t.s == ','
          ls.push stack
          stack = []
        else if t.op and t.s == ket
          ls.push stack
          return [{s:bra,ls:ls}].concat(tokens[i+1...])
        else
          stack.push t
    tokens

  _parseBlock = (tokens, indent=0)->
    tokens = tokens.slice(0)
    i = -1
    while ++i < tokens.length
      t0 = tokens[i]
      t1 = tokens[i+1]
      t2 = tokens[i+2]
      t3 = tokens[i+3]
      t4 = tokens[i+4]
      if t1.id and t1.s in ['class', 'def'] and t2.id and t3.ls and t4.op and t4.s == ':'
        j = i
        while ++j < tokens.length
          t = tokens[j]
          if t.idt and t.s.length <= t0.s.length
            break
        block = _parseBlock(tokens[i+6...j])
        node = {s:t2.s, blk:block, type:t1.s}
        tokens = tokens[...i].concat([node].concat(tokens[j-1...]))
      while ++i < tokens.length
        t = tokens[i]
        break if t.nl
    i = -1
    while ++i < tokens.length
      t = tokens[i]
      if t.idt
        tokens.splice(i,1)
        i--
    tokens

  _blockToObject = (tokens)->
    tokens = tokens.slice(0)
    local = {}
    i = -1
    while ++i < tokens.length
      t0 = tokens[i]
      t1 = tokens[i+1]
      t2 = tokens[i+2]
      t3 = tokens[i+3]
      if t0.id and t1.op and t1.s in [':','=']
        local[t0.s] = _toValue(tokens[i+2...])
      else if t0.lit
        local['__docstring__'] = t0.s
      else if t0.blk
        local[t0.s] = _blockToObject(t0.blk)
      while ++i < tokens.length
        t = tokens[i]
        break if t.nl
    local

  _toValue = (tokens)->
    if not tokens or tokens.length == 0
      return null
    t = tokens[0]
    if t.lit
      return t.s
    else if t.ls
      if t.s == '{'
        return _dictToObject(t.ls)
      else if t2.s in '(['
        return _listToArray(t.ls)
    else if t.id
      if t.s == 'None'
        return null
      if t.s == 'False'
        return false
      if t.s == 'True'
        return true
      i = -1
      tmp = []
      while ++i < tokens.length
        t = tokens[i]
        break if t.nl
        if t.ls and t.s == '{'
          tmp.push _dictToObject(t.ls)
        else if t.ls and t.s in '(['
          tmp.push _listToArray(t.ls)
        else
          tmp.push t.s
      if tmp.length == 1
        return tmp[0]
      return tmp
    null

  _dictToObject = (ls)->
    dict = {}
    for a in ls
      continue if a.length < 3
      if (a[0].id or a[0].lit) and a[1].op and a[1].s == ':'
        dict[a[0].s] = _toValue(a[2...])
    dict


  _listToArray = (ls)->
    list = []
    for a in ls when a and a.length
      list.push _toValue(a)
    list

  @load = (file)->
    text = fs.readFileSync(file, 'utf8')
    cls.parse(text)

  @parse = (src)->
    tokens = _token(src)
    tokens = _parseBraket(tokens)
    tokens = _parseBlock(tokens)
    # console.log(JSON.stringify(tokens,null,'  '))
    obj = _blockToObject(tokens)
    # console.log(JSON.stringify(obj,null,'  '))
    obj

module.exports = Python
