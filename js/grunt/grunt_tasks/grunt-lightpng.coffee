#
# 画像のgitハッシュ値を比較して変更があったらlightpngで圧縮するタスク
#
# @author kenichirow
# @author okada
#
# 重い処理・外部コマンドをを並列化
# 途中でctrl+cしても続きから処理
#

fs = require 'fs'
path = require "path"
{exec} = require 'child_process'
{Step, expand, readDirtyJson, writeDirtyJson, getSha1} = require './lib/utils'
numCPUs = require('os').cpus().length

module.exports = (grunt) ->

  _ = grunt.util._
  log       = (msg)-> grunt.log.writeln msg
  fail      = (msg)-> grunt.fail.warn msg
  fread     = (file)-> grunt.file.read(file)
  fwrite    = (file, code)-> grunt.file.write(file, code)
  fremove   = (file)-> grunt.file.delete(file, force:true)
  fexists   = fs.existsSync or path.existsSync
  fsize     = (file)-> fs.statSync(file).size
  thru      = (it)-> it
  numfmt    = (num)-> (num+'').replace(/(\d)(?=(\d{3})+(?!\d))/g, '$1,')

  gitroot = '.'
  cwd = '.'

  findRoot = (d)->
    ### .gitがあるディレクトリまでさかのぼる ###
    tree = d.split(path.sep)
    while tree.length > 0
      root = tree.join(path.sep)
      if fexists(path.join(root,'.git'))
        break
      tree.pop()
    if tree.length == 0
      return d
    root

  relgit = (file)->
    ### gitroot からのパスに変換する 簡易実装 ###
    path.resolve(file).replace(gitroot+path.sep, '')

  _exec = (cmd, callback, verbose=false)->
    ### execのラッパー ###
    opts =
      encoding: 'utf8'
      timeout: 0
      maxBuffer: 64*1024*1024
      killSignal: 'SIGTERM'
      # cwd: gitroot
    log cmd if verbose
    exec cmd, opts, (err, stdout='', stderr)->
      if err
        e = new Error 'exec error:' + err
        callback?.step?.error(e)
        throw e
      lines = stdout.trim().split(/\s*\n\s*/).filter(thru)
      return callback(lines)
    null
  
  # *********************************************************************
  grunt.registerMultiTask "lightpng", "minify png!", ->

    self = this
    done = this.async()
    files = this.files

    cwd = fs.realpathSync('.')
    gitroot = findRoot(cwd)
    log 'cwd: '+cwd
    log 'git_root: '+gitroot

    options =
      json: 'log.json'
      filter: thru
      bin: path.join(cwd, "./tools/bin/lightpng")
      trimming: ''
      root: ''
    options = this.options(options)

    # 変換候補
    srcs = {}
    # 前回圧縮後のハッシュ値 {"path/to/image.png":"git-hash-object"}
    prevHash = {}
    # 現在hash値
    currentHash = {}
    candidate = []

    step = Step [
      ->
        if fexists options.json
          try
            prevHash = readDirtyJson(options.json, both:true)
          catch e
            fail e
            return
        else
          prevHash = {}
        step()
      
      ->
        if json = grunt.imageData?.json
          # image-dataタスクですでにsha1取得済みならそっち使う
          re = new RegExp '^'+options.root.replace(/\./g,'\\.')
          for f in files
            st = f.src.replace(re, '')
            if data = json[st]
              f.sha1 = data.sha1
            else
              throw Error 'cant find image-data:'+f.src
          step()
        else
          getSha1 files, {pluck:'src'}, step.next
      
      ->
        re = new RegExp '^'+options.root.replace(/\./g,'\\.')
        for f in files
          st = f.src.replace(re, '')
          if grunt.sprite
            if st of grunt.sprite.srcs # sprite sheet 化 対象ファイルは処理しない
              continue
          f.rel = rel = relgit(f.src)
          hash1 = f.sha1 or ''
          hash2 = prevHash[rel] or ''
          # log "#{f.rel.replace(options.trimming, '')} ... [#{hash1[...7]}] [#{hash2[...7]}]"
          if hash1 != hash2
            candidate.push f
        step()

      ->
        count = Math.min(candidate.length, numCPUs)
        if count > 0
          grunt.imageData?.changed = true
          for i in [0...count]
            lightpng candidate, step.next
        else
          step()

      ->
        writeDirtyJson(options.json, prevHash)
        log 'done.'
        done()

    ]

    lightpng = (que, callback)->
      unless f = que.shift()
        return callback()
      time1 = Date.now()
      file = f.src
      tmp = "#{file}.tmp.png"
      size1 = fsize(file)
      size2 = 0
      s = Step [
        ->
          _exec "#{options.bin} -o 2 #{file} -32i #{tmp}", s.next
        ->
          size2 = fsize(tmp)
          if size2 >= size1
            fremove tmp
            s.next()
          else
            _exec "mv -f #{file}.tmp.png #{file}", s.next
        ->
          getSha1 [f.src], update:false, s.next
        ->
          time2 = Date.now()
          log "lightpng #{file.replace(options.trimming, '')}"
          msg = if size2 >= size1 then 'not changed'.cyan else ''
          percent = ~~((size2/size1-1)*10000)/100
          log "  time: #{time2-time1}msec  size: #{numfmt(size1)} -> #{numfmt(size2)} (" +
            (if size1 > size2 then "#{percent}%".green else "#+{percent}%".red) +
            ") #{msg}"
          sha1 = s.arg[f.src]
          prevHash[f.rel] = sha1

          # sprite 出力ファイルなら、lightpng 2回がけなどの影響で
          # さらに縮んで sha1 変わってしまうことがあるのでjsonを更新しなければならない
          re = new RegExp '^'+options.root.replace(/\./g,'\\.')
          url = f.src.replace(re, '')
          if grunt.sprite and (url of grunt.sprite.dests)
            if grunt.sprite.dests[url] != sha1
              grunt.sprite.updates[url](sha1)

          if que.length % 8 == 0
            # 毎回json出力は負荷が高いので8ファイルに一回json書く
            writeDirtyJson(options.json, prevHash)
          lightpng que, callback
      ]
      s.error = (e)->
        fail "error>> lightpng #{file.replace(options.trimming, '')}"
        throw e

    githashobject = (que, callback)->
      unless file = que.shift()
        return callback()
      _exec "git hash-object #{file}", (lines)->
        sha1 = lines[0]
        is_skip = if sha1 == prevHash[file] then ' (skip) ' else ' '
        log 'M '+sha1[...6]+is_skip+file.replace(options.trimming, '')
        currentHash[file] = sha1
        githashobject(que, callback)

