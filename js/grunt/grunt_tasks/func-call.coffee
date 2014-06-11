#
# * func-call.coffee
# * options.func を実行するだけのタスク
# * 
# * @author okada
# 
fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->

  grunt.registerMultiTask "func", "options.func を実行するだけのタスク", ->
    options = this.options(
      func: ->
    )
    done = this.async()
    files = this.files.slice(0)
    task = ->
      unless f = files.shift()
        return done()
      file =
        src: f.src[0]
        dest: f.dest || f.src[0]
        read: -> grunt.file.read(file.src)
        lines: -> grunt.file.read(file.src).split(/\n/)
        write: (text)-> grunt.file.write(file.dest, text)
      g =
        log: (msg)-> grunt.log.writeln msg
        fail: (msg)-> grunt.fail.warn msg
        del: (file)-> grunt.file.delete(file, force:true)
        fexists: fs.existsSync or path.existsSync
        fsize: (file)-> fs.statSync(file).size
        mtime: (file)-> fs.statSync(file).mtime.getTime()
        grunt: grunt
        next: next
        done: done
        path: path
        fs: fs
        safeSplit: safeSplit
        findBracket: findBracket

      options.func.call(this, file, g, options)
    next = ->
      process.nextTick task
    next()


safeSplit = (text, sep=',', trim=true)->
  result = []
  stack = ''
  bra = ''
  depth = 0
  for c in text
    if bra
      if c == ket and --depth == 0
        bra = ''
      if c == bra
        depth += 1
      stack += c
      continue
    if c of brackets
      stack += c
      bra = c
      depth += 1
      ket = brackets[c]
    else if c == sep
      stack = stack.trim() if trim
      result.push stack
      stack = ''
    else
      stack += c
  stack = stack.trim() if trim
  result.push stack
  result

findBracket = (text)->
  result =
    begin: -1
    end: -1
  bra = ''
  depth = 0
  for c,i in text
    if bra
      if c == ket and --depth == 0
        result.end = i
        break
      if c == bra
        depth += 1
      continue
    if c of brackets
      result.begin = i
      bra = c
      depth += 1
      ket = brackets[c]
  if result.begin > -1
    result.left = text[...result.begin]
    result.bra = bra
    if result.end > -1
      result.right = text[result.end+1...]
      result.outer = text[result.begin...result.end+1]
      result.inner = text[result.begin+1...result.end]
      result.ket = ket
    else
      result.outer = text[result.begin...]
      result.inner = text[result.begin+1...]
  result









brackets =
  "'":"'"
  '"':'"'
  '{':'}'
  '(':')'


