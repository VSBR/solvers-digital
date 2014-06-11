#
# * resize-image
# *
# * @author okada
#

fs = require 'fs'
path = require "path"
{exec} = require 'child_process'
{dirname, join, extname} = require 'path'
mtime = (filepath)-> fs.statSync(filepath).mtime.getTime()
existsSync = fs.existsSync || path.existsSync
{Step, readDirtyJson, writeDirtyJson, getSha1, expand} = require './lib/utils'
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
    log cmd if verbose
    exec cmd, opts, (err, stdout='', stderr)->
      if err
        e = new Error 'exec error:' + err
        callback?.step?.error(e)
        throw e
      lines = stdout.trim().split(/\s*\n\s*/).filter(thru)
      return callback(lines)
    null
  
  grunt.registerMultiTask "resizeImage", "@1x画像を生成するよ!", ->

    self = this
    done = this.async()
    files = this.files

    cwd = fs.realpathSync('.')
    gitroot = findRoot(cwd)
    log 'cwd: '+cwd
    log 'git_root: '+gitroot

    options =
      filter: thru
      bin: path.join(cwd, "./tools/bin/lightpng")
      trimming: ''
      background: false
      json: 'resize.json'
      size: '50%'
      root : ''
    options = this.options(options)

    # 変換候補
    srcs = {}
    # 前回圧縮後のハッシュ値 {"path/to/image.png":"git-hash-object"}
    prevHash = {}
    # 現在hash値
    currentHash = {}
    dests = {}

    srclist = []
    candidate = []

    step = Step [
      # --------------------------------------------------------------------------------
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
      
      # ->
      #   expand(self.data, step.next)
      
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
        for f in files
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
            resize candidate, step.next
        else
          step()

      # ->
      #   # いらないキーの削除
      #   # for key of prevHash
      #   #   src = 

      ->
        writeDirtyJson(options.json, prevHash)
        getSha1 [], update:true, step.next

      ->
        log 'done.'
        done()

    ]
    step.error = (e)->
      console.log e.message.red
      throw e

    resize = (que, callback)->
      unless f = que.shift()
        return callback()
      time1 = Date.now()
      dest = f.dest
      grunt.file.mkdir dirname(dest)
      reldest = relgit(dest)
      ext = extname(f.src)
      s = Step [
        ->
          #grunt.file.mkdir dirname(dest)
          quality = ''
          quality = '-quality 80%' if ext == '.jpg'
          bin = join(cwd, './tools/bin/convert')
          _exec "#{bin} #{quality} -geometry #{options.size} '#{f.src}' '#{f.dest}'", s.next

        ->
          bin = join(cwd, './tools/bin/lightpng')
          if ext == '.png'
            _exec "#{bin} -o 2 '#{f.dest}' -32i '#{f.dest}'", s.next
          else
            s.next()
        ->
          getSha1 [f.src], update:false, s.next

        ->
          time2 = Date.now()
          log "resized #{f.rel.replace(options.trimming, '')}"
          sha1 = s.arg[f.src]
          prevHash[f.rel] = sha1
          # fwrite options.json, JSON.stringify(prevHash,null,' ')
          resize que, callback
          step()
      ]
      s.error = (e)->
        console.log e.message.red
        fail "error>> resize #{f.rel.replace(options.trimming, '')}"
        throw e

    
    true
  true

