
os = require 'os'
fs = require 'fs'
path = require 'path'
{exec, spawn} = require 'child_process'

numCPUs = os.cpus().length

find = (basePath, re=null)->
  ### 指定ディレクトリ以下の全ファイル列挙 ###
  list = []
  for p in fs.readdirSync(basePath)
    p = path.join basePath, p
    if (stat = fs.statSync(p)).isFile()
      if re
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

read = -> fs.readFileSync(this.src, 'utf8')
write = (text)-> fs.readFileSync(this.dest, text,'utf8')

_rename = (func)->
  (dest, src)->
    f = {src,dest}
    dirs = src.split(path.sep)
    name = dirs[-1...][0]
    dirs = dirs[...-1]
    chunks = name.split(/\./)
    f.sep = path.sep
    f.dirs = dirs
    f.dirname = dirs.join(path.sep)
    f.dir = dirs.join(path.sep)+path.sep
    f.name = name
    f.base = chunks[...-1].join('.')
    f.ext = if chunks.length > 0 then '.'+chunks[-1...][0] else ''
    f.slice = (i,j)->
      dirs.slice(i,j).join(path.sep)
    f.replace = (from,to)->
      if (i = src.indexOf(from)) > -1
        return src[..i]+to+src[i+from.length...]
      src
    func(f)

flow = (steps)->
  ### async.flow的なショートカット ###
  _after = (i)->
    return throw new Error '' if _cb
    _step = steps[step.index++]
    _step.index = step.index-1
    _args = []
    _cb = ->
      _args = Array::slice.call(arguments).concat(_args)
      if not _cb
        console.log "exceeds step.callback:"+step.index
        console.log "function.toString():"+_step.toString()
        # console.log "arguments:"+JSON.stringify(arguments, null, '  ')
        step.error()
        throw new Error ''

      if --_cb.count == 0
        step.a = _args[0] # shortcut
        step.arg = _args[0] # shortcut
        step.args = _args # shortcut
        process.nextTick ->
          _cb = null
          try
            step.current = _step
            _step.apply(step.binds, _args)
          catch e
            console.log _step.toString()
            console.log e.message
            step.error?(e)
            throw e
      return
    _cb.step = step
    _cb.count = i
    _cb

  step = -> _after(1).apply(step.binds, arguments)
  step.steps = steps
  step.after = _after
  step.index = 0
  step.binds = null
  step.__defineGetter__ 'next', -> _after(1)
  step()
  step

Step = (steps)->
  if not arguments.length > 1
    steps = Array::slice(arguments)
  proto = Step.prototype
  if this instanceof Step
    self = this
  else
    self = -> self.after(1)()
    self.__proto__ = proto
  _steps = length:0
  j = -1
  for s,i in steps
    if typeof s == 'object' and not Array.isArray(s)
      for own name,func of s
        _steps[name] = func
        self[name] = func
    else
      _steps[++j] = s
      _steps.length += 1
      s.index = j

  self.steps = _steps

  self.args = []
  self.arg = null
  self.index = -1
  self.count = 0
  self.current = null
  self.binds = null
  self.processing = false
  Object.defineProperties self,
    next: _getter self._get_next
    done: _getter self._get_callback

  self.after(1)()

  self

Step::_get_next = ->
  this.after(1)

Step::after = (count)->
  this.count += count
  this.done

Step::_get_callback = ->
  self = this
  if this.processing
    throw new Error 'Step error: get callback timing is wrong...'
  index = this.index
  if this.bindedCallback
    return this.bindedCallback
  this.bindedCallback = ->
    args = [index].concat(Array::slice.call(arguments))
    setImmediate ->
      self._callback.apply(self, args)

Step::_callback = (bindedIndex)->
  self = this
  if this.processing
    throw new Error 'Step error: callback timing is wrong...'
  if this.index != bindedIndex
    throw new Error 'Step error: callback index is not current index...'
  this.count -= 1
  if this.count < 0
    throw new Error 'Step error: times of calling callback is exceeded...'
  if this.count == 0
    args = Array::slice.call(arguments,1)
    this.processing = true
    this.bindedCallback = null
    process.nextTick ->
      self.processing = false
      if self.count != 0
        throw new Error 'Step error: interrupt callback error...'
      self.arg = args[0]
      self.args = args
      self.index += 1
      if self.steps.length < self.index
        process.nextTick ->
          self.end?.apply(self, args)
          for own prop of self
            delete self[prop]
          self.__proto__ = null
        return
      self.current = self.steps[self.index]
      if typeof self.current == 'function'
        # console.log self.current+''
        self.current.apply(self, args)
      else
        throw new Error 'Step error: steps['+self.index+'] is not function...'

  undefined


class MODE
  constructor: ->
    for name,i in arguments
      isName = 'is'+name[0].toUpperCase()+name[1...]
      this[isName] = false
      mode = {__proto__:this, index:i}
      mode[isName] = true
      this[name] = mode
    this


readDirtyJson = (file, opt={ours:true})->
  ### mergeを試み、jsonを読む ###
  mode = new MODE('normal', 'ours', 'theirs')
  mode = mode.normal
  text = fs.readFileSync(file, 'utf8')
  result = []
  for ln in text.split(/\n/)
    # 先頭の7文字取得
    head = ln[...7]
    if head == '<<<<<<<'
      mode = mode.ours
    else if head == '======='
      mode = mode.theirs
    else if head == '>>>>>>>'
      mode = mode.normal
    else
      if mode.isNormal
        result.push ln
      else if mode.isOurs and (opt.ours or opt.both)
        result.push ln
      else if mode.isTheirs and (opt.theirs or opt.both)
        result.push ln
  text = result.join('\n')
  text = text.replace(/"\s*\n\s*"/g, '","')
  text = text.replace(/\}\s*\n\s*"/g, '},"')
  text = text.replace(/\]\s*\n\s*"/g, '],"')
  text = text.replace(/(\d)\s*\n\s*"/g, '$1,"')
  obj = JSON.parse(text)

  _deldummy = (a)->
    for own k,v of a
      if not Array.isArray(v) and typeof v == 'object'
        _deldummy v
    delete a["!!!!"]
    delete a["~~~~"]
  _deldummy obj
  obj

sortKeys = (obj, depth)->
  keys = Object.keys(obj).sort()
  result = {}
  depth -= 1
  result['!!!!'] = 'begin of json.'
  for key in keys
    v = obj[key]
    if not Array.isArray(v) and typeof v == 'object' and depth > 0
      v = sortKeys(v)
    result[key] = v
  result['~~~~'] = 'end of json.'
  result

writeDirtyJson = (file, obj, sortDepth=65000)->
  obj = sortKeys(obj, sortDepth)
  text = JSON.stringify(obj, null, ' ')
  fs.writeFileSync file, text, 'utf8'

_dirname = (filepath)->
  i = filepath.lastIndexOf(path.sep)
  if i != -1
    return filepath.slice(0,i)
  filepath

_sha1_cache = null
_sha1_cache_path = 'tmp/hash-object.json'
_sha1_cache_updating = false

getSha1 = (orig, opts, callback)->
  ### 与えられたfilesのsha1をcallbackで返す ###
  if typeof orig != 'object'
    throw new Error 'error getSha1: arguments[0] must be object or array...'

  if typeof opts == 'function'
    callback = opts
    opts = {}

  # hello

  if not _sha1_cache
    text = try fs.readFileSync(_sha1_cache_path, 'utf8') catch e then ''
    _sha1_cache = try JSON.parse(text) catch e then {}
    #_sha1_cache = try eval('('+text+')') catch e then {}
    update_at = _sha1_cache['!!update_at!!'] or 0
    if Date.now() - update_at > 3 * 24 * 60 * 60 * 1000
      # git hash-object を全ファイルにかけるのはすごく時間かかるので、
      # 初回及び3日以上アップデートされてなかったら
      # git ls-tree HEAD で一括でsha1取ってキャッシュ作成
      _generate_sha1_cache ->
        getSha1(orig, opts, callback)
      return

  defers = numCPUs
  updated = false
  files = []
  if opts.type == 'object-key'
    files = Object.keys(orig)
  else if pluck = opts.pluck
    if not Array.isArray(orig)
      console.log('args[0] must be array when plucking. args[0]:', orig)
    files = orig.slice(0)
    opts.key or= 'sha1'
    # for val in orig when val = val[pluck]
    #   files.push val
  else
    files = orig.slice(0)
  result = {}
  _dir_changed = {}
  _file_cache = {}
  task = ->
    unless f = files.shift()
      if --defers == 0
        done()
      return
    if opts.key
      o = f
      unless f = o[opts.pluck]
        return task()
    set = (s)->
      if opts.key
        o[opts.key] = s
      else
        result[f] = s
    if cache = _file_cache[f]
      set cache.sha1

    # fileのmtime比較
    unless fs.existsSync(f) and  stat = fs.statSync(f)
      _file_cache[f] = {sha1:null}
      set null
      return next()
    mtime = stat.mtime.getTime()
    if cache = _sha1_cache[f]
      if cache.mtime == mtime
        _file_cache[f] = cache
        set cache.sha1
        return next()

    exec "git hash-object '#{f}'", (err, stdout, stderr)->
      sha1 = stdout.trim()
      set sha1
      cache =
        mtime: mtime
        sha1: sha1
      _sha1_cache[f] = _file_cache[f] = cache
      updated = true
      return next()
  next = -> setImmediate task
  done = ->
    if not _sha1_cache_updating
      if opts.update == true or (updated and opts.update != false)
        _sha1_cache['!!update_at!!'] = Date.now()
        text = JSON.stringify(_sha1_cache, null, ' ')
        _sha1_cache_updating = true
        fs.writeFile _sha1_cache_path, text, encoding:'utf8', ->
          _sha1_cache_updating = false

    if opts.type == 'object-key'
      for key in files
        orig[key].sha1 = result[key]
      result = orig
      return callback result

    else if pluck = opts.pluck
      # for o in orig
      #   src = o[pluck]
      #   o.sha1 = result[src]
      result = orig
      return callback result
    # console.log result

    callback result


  for i in [0...numCPUs]
    task()

  return

_generate_sha1_cache = (done)->
  ### git ls-tree HEAD で一括でsha1取ってキャッシュ作成 ###

  cwd = fs.realpathSync('.')
  root = do ->
    ## .gitがあるディレクトリまでさかのぼる
    tree = cwd.split(path.sep)
    while tree.length > 0
      root = tree.join(path.sep)
      if fs.existsSync(path.join(root,'.git'))
        break
      tree.pop()
    if tree.length == 0
      return cwd
    root

  tmp = {}
  step = flow [
    ->
      _spawnLines 'git', ['ls-tree', 'HEAD', '-r'],
        cwd: root
        line: (ln)->
          [mode, type, sha1, file] = ln.split(/\s+/)
          if not file or not sha1
            return
          if not /\.(png|jpg|jpeg|gif)$/.test(file)
            return
          tmp[file] = sha1
        end: step.next
    ->
      _spawnLines 'git', ['ls-files', '-m'],
        cwd: root
        line: (ln)->
          file = ln
          if tmp[file]
            delete tmp[file]
        end: step.next
    ->
      _spawnLines 'git', ['ls-files', '-u'],
        cwd: root
        line: (ln)->
          file = ln
          if tmp[file]
            delete tmp[file]
        end: step.next
    ->
      _sha1_cache = {}
      for file,sha1 of tmp
        abs = path.join(root, file)
        rel = relpath(cwd, abs)
        unless fs.existsSync(rel)
          continue
        unless stat = fs.statSync(rel)
          continue
        mtime = stat.mtime.getTime()
        _sha1_cache[rel] =
          mtime: mtime
          sha1: tmp[file]
      tmp = {}
      step()

    ->
      _sha1_cache['!!update_at!!'] = Date.now()
      text = JSON.stringify(_sha1_cache, null, '')
      fs.writeFileSync _sha1_cache_path, text, 'utf8'
      done()

  ]

relpath = (base, target)->
  base = base.split(path.sep)
  target = target.split(path.sep)
  min = Math.min(base.length, target.length)
  for i in [0...min]
    if base[i] != target[i]
      break
  base = base[i...]
  target = target[i...]
  for b in base
    target.unshift '..'
  target.join(path.sep)

_spawnLines = (cmd, args, opt)->
  console.log cmd + ' '+args.join(' ')
  # opt.stdio = "inherit"
  child = spawn(cmd, args, opt)
  child.stdout.setEncoding 'utf8'
  chunk = ''
  line = opt.line
  end = opt.end
  delete opt.line
  delete opt.end
  child.stdout.on 'data', (data)->
    data = chunk + data
    arr = data.split(/\n/)
    for ln in arr[...-1]
      # console.log ln
      line ln
    chunk = arr[arr.length-1]
    arr = null
  child.on 'close', (code)->
    if code != 0
      throw new Error 'exec error!'
      return
    if chunk
      line chunk
    end()
  null



FilePairProto = {}
_getter = (func)->
  enumerable : true
  configurable : true
  get: func
Object.defineProperties FilePairProto,
  dirs: _getter ->
    dirs = this.src.split(path.sep)
    this.dirs = dirs
  dirname: _getter ->
    this.dirname = this.dirs.join(path.sep)
  dir: _getter ->
    this.dir = this.dirs.join(path.sep)+path.sep
  name: _getter ->
    this.name = this.dirs[-1...][0]
  names: _getter ->
    this.names = this.name.split(/\./)
  base: _getter ->
    this.base = this.names[...-1].join('.')
  ext: _getter ->
    this.ext = if this.names.length > 0 then '.'+this.names[-1...][0] else ''

_time = Date.now()
_bench = (msg="")->
  now = Date.now()
  console.log "#{msg} bench ... #{now-_time}ms"
  _time = now


expand = (data, callback)->
  ### grunt.file.expand の高速版 ###
  # glob+minimatchが遅すぎるので可能ならfindをspawnする
  # 非同期版しか無いので注意
  pairs = (srcs, f)->
    files = []
    filter = f.filter or (it)-> true
    if rename = f.rename
      for src in srcs when filter src
        dest = rename(f.dest, src)
        if Array.isArray(dest)
          for d in dest
            files.push pair(src, dest, f)
        else
          files.push pair(src, dest, f)
    else
      for src in srcs when filter src
        files.push pair(src, f.dest, f)
    files
  pair = (src,dest,origf)->
    if orig[0].flat
      {src:src, dest:dest, orig:origf, __proto__:FilePairProto}
    else
      {src:[src], dest:dest, orig:origf, __proto__:FilePairProto}

  orig = data.filesExt || data.files
  if not Array.isArray(orig)
    orig = [orig]
  if orig.length == 0 
    process.nextTick ->
      callback []
    return
  if expanded = orig[0].expanded
    process.nextTick ->
      callback expanded
    return
  que = orig.slice(0)

  files = []
  proc = ->
    unless f = que.shift()
      #
      # files.srcDict = srcDict = {}
      # files.destDict = destDict = {}
      # for f in files
      #   srcDict[f.src] = f
      #   destDict[f.dest] = f if f.dest
      #
      # for _f in files
      #   _f.orig.expanded = files

      data.files = files
      # console.log files
      if orig[0].sha1
        # sha1: true ならsha1も取得しとく
        getSha1 files, pluck:'src', (files)->
          getSha1 files, pluck:'dest', key:'destSha1', (files)->
            return callback files
      else
        process.nextTick ->
          callback files
      return
    
    if ignore = f.ignore
      if typeof ignore == 'string'
        ignore = [ignore]
      ignore = ignore.filter (it)->it
      if ignore.length > 0
        tmp = []
        for p in ignore
          tmp.push p.replace(/\./g,'\\.').replace(/\*\*\/\*/g,'.+').replace(/\*/g,'[^/]+')
        paturn = '^('+tmp.join('|')+')$'
        f.filter = do (paturn)->
          re = new RegExp(paturn)
          (src)-> not re.test(src)

    if src = f._src or f.src
      if typeof src == 'function' and srcs = src(data)
        if not Array.isArray(srcs)
          srcs = [srcs]
        files = files.concat(pairs(srcs, f))
        process.nextTick ->
          proc()
        return true
      if typeof src == 'string'
        # "path/to/sources/**/*.ext" を "find path/to/sources -iname *.ext" に変換
        if m = src.match(/^(.*)\/\*\*\/\*(\.[^\.]+)$/)
          if not /[\*\[\]\*\{\}\,]/.test(m[1]+m[2])
            dirname = m[1]
            ext = m[2]
            f.exec = "find #{dirname} -iname *#{ext}"
            delete f.src
    if cmds = f.exec
      if typeof cmds == 'string'
        cmds = [cmds]
      srcs = []
      shift = ->
        unless cmd = cmds.shift()
          process.nextTick ->
            proc()
          return
        srcs.push ''
        cmd = cmd.split(/\s+/)
        _spawnLines cmd[0], cmd.slice(1),
          line: (src)->
            if not f.filter or f.filter(src)
              if src.split(path.sep).slice(-1)[0][0] == '.' # . から始まるファイルは除く
                return
              if f.rename
                dest = f.rename(f.dest, src)
              else
                dest = f.dest
              if Array.isArray(dest)
                files.push pair(src, d, f) for d in dest
              else
                files.push pair(src, dest, f)
          end: -> shift()
      shift()
      return true
    if src = f.src
      files.push pair(src, f.dest, f)
      process.nextTick proc
    else
      throw Error "error src: " + src
  process.nextTick proc


exports._rename = _rename
exports.flow = flow
exports.Step = Step
exports.readDirtyJson = readDirtyJson
exports.writeDirtyJson = writeDirtyJson
exports.getSha1 = getSha1
exports.expand = expand

