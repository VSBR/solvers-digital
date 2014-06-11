#
# * grunt-capture
# * スクショを撮る
# * @author okada
#

fs = require 'fs'
path = require "path"
{exec} = require 'child_process'
{Step} = require './lib/utils'

repeat = (str, count)->
  if count == 1
    return str
  (new Array(count+1)).join(str)

dateFmts = 'FullYear Month Date Hours Minutes Seconds'.split(' ').map((it)-> Date.prototype['get'+it]);
dateFmt = (date, paturn)->
  dict = 'ymdhis'
  return paturn.replace /(y+|m+|d+|h+|i+|s+)/g, (m)->
    i = dict.indexOf(m[0])
    fn = dateFmts[i]
    len = m.length
    ofs = 0
    if !fn
      return m
    if i == 1
      ofs = 1
    if i == 0 && len == 1
      len = 2
    str = if len == 1
      ''+(fn.call(date)+ofs)
    else
      (repeat('0', len-1)+(fn.call(date)+ofs)).slice(-len)
    str


numCPUs = require('os').cpus().length

module.exports = (grunt) ->

  log       = (msg)-> grunt.log.writeln msg
  fail      = (msg)-> grunt.fail.warn msg

  _exec = (cmd, callback, verbose=false)->
    ### execのラッパー ###
    opts =
      encoding: 'utf8'
      killSignal: 'SIGTERM'
    log cmd
    exec cmd, opts, (err, stdout='', stderr)->
      if err
        return callback null
      lines = stdout.trim().split(/\s*\n\s*/).filter((it)-> it)
      return callback(lines)
    null
  
  grunt.registerMultiTask "capture", " スクショを撮る", ->

    self = this
    done = this.async()

    options =
      bin: 'tools/bin/phantomjs tools/bin/capture.js'
    options = this.options(options)

    urls = @data
    candidate = Object.keys(urls)
    location = ''
    dir = '.'
    defers = numCPUs

    step = Step [
      ->
        _exec "ps aux | grep manage.py | grep runserver | grep -v grep", step.next
      ->
        if step.arg == null
          fail 'cant find runserver url'
          return
        chunks = step.arg[0].split(/\s+/)
        chunks = chunks.slice(chunks.indexOf('runserver'))
        if chunks.length == 2
          arg = chunks[1]
          if arg.indexOf(':') > -1
            location = "http://#{arg}"
          else
            location = "http://127.0.0.1:#{arg}"
          step.next()
        else
          fail 'cant find runserver url'
      ->
        dir = '~/Desktop/'+dateFmt(new Date, 'yymmddhhiiss')
        # grunt.file.mkdir dir
        step.next()
      ->
        capture() for i in [0...defers]
    ]

    capture = ->
      unless name = candidate.shift()
        done() if --defers == 0
        return
      url = urls[name]
      if !url or typeof url != 'string'
        return capture()
      cap = Step [
        ->
          _exec "#{options.bin} #{location}#{url} #{dir}/#{name}.png", cap.next
        ->
          capture()
      ]

    true
  true

