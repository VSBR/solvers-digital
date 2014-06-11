#
# すべての画像のsha1ハッシュ値、サイズを取得し、jsonに保存する
# このjsonは他の様々なタスクで使うかも
#

fs = require 'fs'
path = require "path"
{exec,spawn} = require 'child_process'
{getSha1, readDirtyJson, writeDirtyJson, expand, Step} = require './lib/utils'

module.exports = exports = (grunt) ->

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

  cwd = fs.realpathSync('.')
  
  # *********************************************************************
  grunt.registerMultiTask "image-data", "get image info", ->

    self = this
    done = this.async()
    files = this.data.filesExt = [this.data._filesExt]

    options =
      root: '.'
    options = this.options(options)

    root = fs.realpathSync(options.root)
    dest = files[0].dest
    try
      prevData = readDirtyJson(dest, both:true)
    catch e
      prevData = {}

    json = {}
    srcs = []

    if exports.changed == false
      log 'not changed. skip.'
      return done()

    step = Step [
      ->
        log 'listing files ...'
        expand self.data, step.next

      ->
        files = step.arg
        log 'getting sha1 hashes ...'
        getSha1 files, pluck:'src', step.next

      ->
        json = {}
        log 'getting images size ...'
        for f in files
          srcs.push f.src
          key = path.join(cwd, f.src).replace(root, '')
          if data = prevData[key]
            if data.sha1 != f.sha1
              size = getSize(f.src)
              data.sha1 = f.sha1
              data.width = size.w
              data.height = size.h
          else
            data = {}
            size = getSize(f.src)
            data.sha1 = f.sha1
            data.width = size.w
            data.height = size.h
          json[key] = data
        step()

      ->
        log 'writing json ...'
        writeDirtyJson dest, json, 1
        grunt.imageData = exports
        exports.json = json
        exports.srcs = srcs
        exports.changed = false
        step()

      ->
        if options.masterJson
          masterData = []
          tmp = {}
          for own key,data of json when key = options.masterFilter(key)
            tmp[key] = data
          for key in Object.keys(tmp).sort()
            masterData.push
              pk: key
              fields: tmp[key]
          str = JSON.stringify(masterData, null, 2)
          log 'writing master json ...'
          grunt.file.mkdir path.dirname(options.masterJson)
          fs.writeFileSync options.masterJson, str, 'utf8'
        step()

      ->
        done()
    ]

exports.json = null
exports.srcs = null
exports.changed = undefined

cache = {}

exports.getSize = getSize = (filename)->
  if data = cache[filename]
    return data
  ext = filename.split(/\./)
  ext = ext[ext.length-1].toLowerCase()

  try
    if fs.existsSync(filename)
      fd = fs.openSync(filename, 'r')

      func = reader[ext]
      if func and data = func(fd)
        cache[filename] = data
      else
        console.log "#{filename} サイズ取得ができません"
        data = {w:0, h:0}
      fs.closeSync(fd)
    else
      console.log "#{filename} is not exists"
      data = {w:0, h:0}
  catch e
    console.log "#{filename} 開けない"
    data = {w:0, h:0}
  data


reader =
  png: (fd)->
    buf = new Buffer(8)
    b = fs.readSync(fd, buf, 0, 8, 8+4+4)
    if b == 8
      # big endian!!
      w = (buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | (buf[3])
      h = (buf[4] << 24) | (buf[5] << 16) | (buf[6] << 8) | (buf[7])
      return {w,h}
    null

  gif: (fd)->
    # http://www.tohoho-web.com/wwwgif.htm
    buf = new Buffer(4)
    b = fs.readSync(fd, buf, 0, 4, 3+3)
    if b == 4
      # little endian!!
      w = (buf[1] << 8) | (buf[0])
      h = (buf[3] << 8) | (buf[2])
      return {w,h}
    null

  jpg: (fd)->
    # http://sadoyama.sakura.ne.jp/world/htm/note/002_02_jpg.htm#code
    buf = new Buffer(4)
    pos = 2
    while 1
      b = fs.readSync(fd, buf, 0, 4, pos)
      return if b != 4
      mark = (buf[0] << 8) | buf[1]
      # console.log(mark.toString(16))
      size = (buf[2] << 8) | buf[3]
      if 0xffc0 <= mark <= 0xffcf
        b = fs.readSync(fd, buf, 0, 4, pos+5)
        return if b != 4
        # big endian!!
        h = (buf[0] << 8) | buf[1]
        w = (buf[2] << 8) | buf[3]
        return {w, h}
      if mark == 0xffd9
        break
      pos += size + 2
    null

reader.jpeg = reader.jpg

