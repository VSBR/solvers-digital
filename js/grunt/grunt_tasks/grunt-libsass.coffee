###

grunt-kemono-libsass
------------------------------------------------------------------------------------

libsass (sassのc/c++実装ライブラリ) をnode.jsから使うnode-sassを
grunt-task化したもの。

既にあるが、( https://github.com/sindresorhus/grunt-sass )
カスタムするため1から作った
完全にkemono仕様です。

## 完了
* とりあえず動く
* js_funcとの連携のため、ネイティブモジュールのマルチスレッド化はできないのでマルチプロセス化
* jsのfunctionをsassのbuilt-in関数化できるように。(image-width, sprite対策)
* コンパイルタスクを並列実行するように。
* jsでimage-width,image-height,-neopoodle-sprite-infoを書く
* 簡易な依存関係を記録・更新し、コンパイルの必要のないファイルはスキップできるように

## 依存解決
高速化・単純化のため、詳細な依存解決はしない。
記述されている @import を探し、ツリーを生成するのみ。
更新日時が前回コンパイルより新しいファイルのみ依存関係更新する。
また、参照が深すぎるファイルは警告を出す。

ここで言う詳細な依存解決とは、globalに定義したmixin、functionなどを
合流を見越して参照することです。
つまり、着目しているpartialファイルをimportしているファイルで前の行で
importしているはずだから使えるという考えで、突然function, mixinを使うこと。
すべてのファイルを単独コンパイルできるような構造を目指すべき。

---
###

os = require 'os'
fs = require 'fs'
numCPUs = os.cpus().length
path = require 'path'
cluster = require 'cluster'
CSON = require './grunt-libsass/lib/cson'
fexists   = fs.existsSync or path.existsSync
utils = require './grunt-libsass/lib/utils'
{getSha1, readDirtyJson, writeDirtyJson} = require './lib/utils'

HOSTNAME = os.hostname()
cwd = fs.realpathSync('.')
middlewares = {}

history = null
historyUpdateAt = 0

workers = {}
freeWorkers = []
isReady = false
onReady = ->

grunt = null

# -------------------------------------------------------------------------------------
# worker
_compile = (options, cb)->
  return if not options or not options.file
  try
    if options.builtIns
      mod = require(path.join(cwd,options.builtIns))
      mod.setOptions options
      sass.builtIns = mod.builtIns
      mod.start?()
    else
      sass.builtIns = {}
    css = sass.renderSync options
    for m in options.middleware when m = middlewares[m]
      css = m.compile(css, options)
    fs.writeFileSync options.dest, css
    result = {}
    if mod
      result = mod.end?()
    cb(result)
  catch e
    console.log '----------------------------------------'
    re = new RegExp cwd+'/', 'g'
    msg = e.message.replace(re, '') || 'unknown error'
    console.log msg.red
    console.log e.stack.replace(re, '').magenta
    console.log '----------------------------------------'
    _error(msg)

# master
compile = (msg, cb)->
  w = freeWorkers.shift()
  w.ondone = cb
  w.send msg

_error = -> throw new Error()

# -------------------------------------------------------------------------------------
if not cluster or not cluster.isMaster
  do ->
    dir = path.join(__dirname, './grunt-libsass/middleware')
    ls = fs.readdirSync(dir)
    for f in ls when m = f.match(/^(.+)\.(js|coffee)$/)
      middlewares[m[1]] = require path.join(dir,f)
    null

# -------------------------------------------------------------------------------------
if cluster and cluster.isMaster
  sass = {}
  _readied = 0

  cluster.setupMaster
    exec: ''
    execArgv: [
      path.join(path.dirname(__filename), 'grunt-libsass/worker.js')
      __filename
    ]
  _bak = process.execPath
  process.execPath = 'node' if !/node$/.test(_bak)
  [0...numCPUs].forEach (i)->
    w = cluster.fork()
    workers[w.id] = w
    freeWorkers.push w
    w.on 'message', (msg)->
      if not msg or msg.err
        _error(msg.err)
      if msg.done
        if cb = w.ondone
          freeWorkers.push w
          w.ondone = null
          cb(msg)
      else if msg.ready
        console.log "worker ##{i} is ready.".green
        if ++_readied == numCPUs
          isReady = true
          onReady()

    w.on 'exit', (code, signal)->
      _error()
  process.execPath = _bak

else if cluster and cluster.isWorker
  sass = require './grunt-libsass/sass'
  process.send ready: true
  process.on 'message', (msg)->
    _compile msg, (result)->
      process.send done: msg.dest, result: result
  _error = (err)-> process.send err:err||'error'

else
  sass = require './grunt-libsass/sass'
  console.log 'not worker mode'
  compile = _compile
  isReady = true
  numCPUs = 1

# -------------------------------------------------------------------------------------
flattenFiles = (files)->
  ### src-destを1by1にする ###
  result = []
  for f in files
    src = f.src
    if !(src instanceof Array)
      src = [src]
    for s,i in src
      dest = f.dest
      if typeof dest == 'string' and dest.indexOf(':') > -1
        dest = dest.split(/:/)
      else if !(dest instanceof Array)
        dest = [dest]
      for d,j in dest
        obj = {}
        tree = s.split(path.sep)
        name = tree[-1...][0]
        chunks = name.split(/\./)
        obj.src = s
        obj.dirname = tree[...-1].join(path.sep)
        obj.dir = tree[...-1].join(path.sep)+path.sep
        obj.name = name
        obj.base = chunks[...-1].join('.')
        obj.ext = if chunks.length > 0 then '.'+chunks[-1...][0] else ''
        obj.srcIndex = i
        obj.dest = d
        obj.destIndex = j
        result.push obj
  result


# -------------------------------------------------------------------------------------

module.exports = (_grunt) ->
  grunt = _grunt
  log       = (msg)-> grunt.log.writeln msg
  fail      = (msg)-> grunt.fail.warn msg
  fread     = (file)-> grunt.file.read(file)
  fwrite    = (file, code)-> grunt.file.write(file, code)
  fremove   = (file)-> grunt.file.delete(file, force:true)
  fsize     = (file)-> fs.statSync(file).size


  _error = -> fail 'exit worker.'

  grunt.registerMultiTask "libsass", "libsass改造版", ->
    
    self = this
    done = this.async()
    files = flattenFiles(this.files)
    if grunt.regarde
      # regarde使用時はコンパイル失敗で停止しないように
      console.log 'enabled regarde.'.yellow
      grunt.regarde.growl = null
      _error = (msg)->
        count = 0
        files.length = 0
        _error = ->
        grunt.regarde.growl = msg
        freeWorkers.length = 0
        for wid,w of workers
          w.ondone = null
          freeWorkers.push w
        log 'resuming... regarde'.red
        #console.log history
        done()

    cwd = fs.realpathSync('.')
    
    options =
      fource: false
      cwd: cwd
      rootPath: '.'
      spriteDataPath: '.'
      middleware: []
      resolveDepends: true
      resolveDerective: true
      compileHistory: 'sass-compile-history.json'
      outputStyle: 'nested'
      sourceComments: 'none'
    options = this.options(options)

    tmp = []
    for f in files
      tmp.push f.src
      tmp.push f.dest

    dests = []
    dest2src = {}

    getSha1 tmp, (hash)->

      if not history #or _mtime(options.compileHistory) > historyUpdateAt
        try
          history = readDirtyJson(options.compileHistory, both:true)
          console.log 'readDirtyJson(both:true): '+options.compileHistory
        catch e
          try
            history = readDirtyJson(options.compileHistory, theirs:true)
            console.log 'readDirtyJson(theirs:true): '+options.compileHistory
          catch e
            console.log 'cant read: '+options.compileHistory
            history = {}

      # 更新ファイル
      files = resolveHistory(files, options, history, hash)
      
      count = numCPUs
      task = ->
        unless f = files.shift()
          if --count == 0
            time = ~~((Date.now() - time0) / 1000)
            log "complete! total time:#{time}s".green
            historyUpdateAt = Date.now()
            # 出力されたcssのsha1をまとめて取得
            getSha1 dests, (destHash)->
              for dest in dests
                src = dest2src[dest]
                history[src].dest_sha1[HOSTNAME] = destHash[dest]
              writeDirtyJson(options.compileHistory, history)
              done()
          return
        src = f.src
        dest = f.dest
        destIndex = f.destIndex
        srcdir = src.split('/').slice(0,-1).join('/')
        grunt.file.mkdir path.dirname(dest)
        if destIndex == 0
          dests.push dest
          dest2src[dest] = src

        options.dest = dest
        options.file = src
        options.paths = srcdir
        options.target = options.targets[f.destIndex]

        t0 = Date.now()
        # history[src].src_sha1[HOSTNAME] = 0
        # throw new Error  'stop'
        compile options, (msg)->
          history[src].images = msg.result.images
          time = Date.now() - t0
          log "#{time}ms".cyan+" #{dest}"
          process.nextTick task

      time0 = 0
      start = ->
        onReady = ->
        time0 = Date.now()
        for i in [0...numCPUs]
          task()
      if isReady
        start()
      else
        onReady = start
    null
  null

# ----------------------------------------------------------------------
_mtime = (filepath)-> fs.statSync(filepath).mtime.getTime()

resolveHistory = (files, options, history, hash)->
  ###  依存解決, ファイル更新日時記録 ###

  hostnames = history['!!HOSTNAMES!!'] or= {}
  now = (new Date()).getTime()

  # 自分のsha1を一番最新の人のsha1にする
  latestHost = null
  maxt = 0
  for h,t of hostnames
    if now > t > maxt # nowより未来はhistoryぶっ壊れてるので不採用
      maxt = t
      latestHost = h
  if latestHost and latestHost != HOSTNAME
    for f in files when info = history[f.src]
      info.src_sha1[HOSTNAME] = info.src_sha1[latestHost]
      info.dest_sha1[HOSTNAME] = info.dest_sha1[latestHost]
  hostnames[HOSTNAME] = now # nowにする

  # 全ファイルを検索しやすいようにdict化
  all = {}
  for f in files
    src = f.src
    dst = f.dest
    all[src] = 1
  # 削除済みファイルのhistoryから除く
  for own k,v of history
    if k[0] != "!" and not all[k]
      console.log "delete history.#{k}"
      delete history[k]

  targets = {}
  skips = {}
  for f in files
    src = f.src
    dest = f.dest

    # もうtarget評価済みならそれに習う
    # 1src複数destになりうるため
    if src of targets
      targets[src].push f
      continue
    if src of skips
      skips[src].push f
      continue

    if not fexists(src)
      # file無いならエラー
      throw new Error "read error #{src}"


    # キー無いなら作っとく
    unless info = history[src]
      info = history[src] = {priority: -1}
    if not info.src_sha1
      info.src_sha1 = {}
      info.src_sha1[h] = v for own h,v of hostnames
    if not info.dest_sha1
      info.dest_sha1 = {}
      info.dest_sha1[h] = v for own h,v of hostnames

    # 実際のsha1を取る
    cur_src_sha1 = hash[src]
    cur_dest_sha1 = hash[dest]

    # 前回コンパイル時のsha1,priority取る
    last_src_sha1 = info.src_sha1[HOSTNAME]
    last_dest_sha1 = info.dest_sha1[HOSTNAME]
    last_priority = info.priority

    # 現在値をセット TODO: コンパイル失敗時にこの値大丈夫なのか
    info.src_sha1[HOSTNAME] = cur_src_sha1

    # 互換性確保...
    if info.imp
      delete info.imp # renamed
      last_src_sha1 = 0

    # srcの前回コンパイル時のsha1と現在のsha1が違うので更新あり
    if cur_src_sha1 != last_src_sha1
      console.log "modified: ".green+"#{src}".yellow
      # ソース読む
      text = fs.readFileSync(src, 'utf8')
      lines = text.split(/\n/)
      # 1行目を記録
      fl = lines[0].trim()
      if fl[...4] != '// @'
        if fl = fl.split(/\/\//)[1]
          fl = '//'+fl
      if fl
        info.fl = fl
      # 依存解決のために@importを探し記録
      imp = {}
      for ln in lines when m = ln.match(/^[\t ]*@import[\t ]+['"]([^'"]+)['"]/)
        p = utils.joinPath(f.dirname, m[1])
        d = utils.dir(p)
        n = utils.base(p)
        if all[p]
          p = p
        else if all[p+'.scss']
          p = p+'.scss'
        else if all[d+'_'+n]
          p = d+'_'+n
        else if all[d+'_'+n+'.scss']
          p = d+'_'+n+'.scss'
        else
          throw new Error 'in '+src+': not found: ' + ln
        imp[p] = 1
      info.imports = imp
      # コンパイル対象に追加
      # partialであっても更新あったら依存解決のため追加される
      targets[src] = [f]
      continue

    # 画像更新検知
    if grunt.imageData # image-data タスクが実行済みの必要あり
      json = grunt.imageData.json
      flg = false
      for own url,image_sha1 of info.images
        cur_image_sha1 = json[url].sha1
        last_image_sha1 = image_sha1
        if cur_image_sha1 != last_image_sha1
          # srcの変更は無いが、画像の差し替えがあったらしい
          console.log "modified image: ".green+"#{src}".yellow+" file:"+url.split(path.sep)[-1...][0]
          targets[src] = [f]
          flg = true
          break
      continue if flg

    # 更新のないpartial
    if f.name[0] == '_'
      # destは存在しないのでdest更新判定の前で評価している
      # コンパイル対象になりえない
      skips[src] = [f]
      continue

    # src更新はないが、何らかの理由(clean?)でdestファイルが存在しない
    if not fexists(dest)
      console.log "not exists dest: ".green+"#{src}".yellow
      # コンパイル対象に追加
      targets[src] = [f]
      continue

    # src更新はないが、何らかの理由(merge等?)でdest更新あり
    if cur_dest_sha1 != last_dest_sha1
      console.log "dest modified: ".green+"#{src}".yellow
      # コンパイル対象に追加
      targets[src] = [f]
      continue

    # srcもdestも更新がないが、コンパイル優先度が高い(releaseコンパイル済み > debugコンパイル済み)
    if options.priority > last_priority
      console.log "high priority: ".green+"#{src}".yellow
      # コンパイル対象に追加
      targets[src] = [f]
      continue

    # それ以外はスキップ
    skips[src] = [f]

  # @import依存解決
  if options.resolveDepends
    flg = true
    while flg
      flg = false
      for src,f of skips
        for dep,ok of history[src].imports
          if targets[dep]
            console.log "#{src} ".yellow+"<<<<".magenta+" #{dep}"
            targets[src] = f
            delete skips[src]
            flg = true
          break if flg
        break if flg
    console.log 'resolved depends!'.green

  # ディレクティブ評価
  # if options.resolveDerective
  #   for src,ff of targets
  #     continue if ff.not
  #     info = history[src]
  #     continue if src[0] == '_' or not info.fl
  #     fl = info.fl.split(/:/)
  #     if fl.length >= 2
  #       dname = fl[0].split(/@/)[1]
  #       code = fl[1...].join(':')
  #       if dname and code
  #         if dname == 'end_at'
  #           paths = src.split(path.sep)
  #           filename = paths[-1...][0]
  #           names = filename.split(/\./)
  #           if names.length == 1
  #             name = filename
  #             ext = ''
  #           else
  #             name = names[...-1].join('.')
  #             ext = '.'+names[-1...][0]
  #           dirname = paths[...-1].join(path.sep)
  #           dir = dirname+path.sep
  #           json = utils.json
  #           json.path = "../data/json"
  #           if num = name.match(/\d+/)
  #             num = +num[0]
  #           result = ''
  #           endAt = 0
  #           try
  #             do (code, name, filename, num, ext, dirname, dir, json)->
  #               result = eval('('+code+')')
  #             if not result
  #               throw new Error 'directive result is undefined'
  #             if result.indexOf(':') > -1
  #               endAt = new Date(result)
  #             else
  #               endAt = new Date(result)
  #               endAt.setHours(23)
  #               endAt.setMinutes(59)
  #               endAt.setSeconds(59)
  #             endAt = endAt.getTime()
  #           catch e
  #             continue

  #           if endAt < Date.now()
  #             console.log "skip".green+" #{src} "+"@end_at: #{result}".red
  #             delete targets[src]

  # 最終的にpartialを除く
  result = []
  for src,ff of targets
    for f in ff when f.name[0] != '_'
      history[src].priority = options.priority
      result.push f

  result

#console.log arguments.callee.toString().split(/\n/).map((it,i)->'   '+i+':'+it).join('\n')



