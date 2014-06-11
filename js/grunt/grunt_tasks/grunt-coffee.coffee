#
# * grunt-contrib-coffee
# * http://gruntjs.com/
# *
# * Copyright (c) 2012 Eric Woroshow, contributors
# * Licensed under the MIT license.
#
# 130304 grunt-contrib-coffeeを変更のあるファイルのみ実行するように書き換えたもの
# 130306 sourcemapに対応

fs = require 'fs'
{getSha1} = require './lib/utils'

module.exports = (grunt) ->
  "use strict"
  grunt.registerMultiTask "coffee", "Compile CoffeeScript files into JavaScript", ->
    path = require("path")
    files = @files
    done = this.async()
    options = @options(
      bare: false
      separator: grunt.util.linefeed
      json: 'tmp/coffee.json'
    )
    grunt.fail.warn "Experimental destination wildcards are no longer supported. please refer to README."  if options.basePath or options.flatten
    grunt.verbose.writeflags options, "Options"
    json = try
      JSON.parse(fs.readFileSync(options.json, 'utf8'))
    catch e
      {}

    for f in files
      
      # 1by1のみ対応
      fsrc = if Array.isArray(f.src) then f.src[0] else f.src
      fdest = f.dest

      if not grunt.file.exists(fsrc)
        grunt.log.warn "Source file \"" + filepath + "\" not found."
        continue

      if json[fsrc] == f.sha1 and json[fdest] == f.destSha1
        grunt.log.writeln "File " + fdest.cyan + " skiped."
        continue

      # if options.mtime and grunt.file.exists(fdest)
      #   mtime1 = fs.statSync(fsrc).mtime.getTime()
      #   mtime2 = fs.statSync(fdest).mtime.getTime()
      #   if mtime1 < mtime2
      #     grunt.log.writeln "File " + fdest.cyan + " skiped."
      #     continue
      options.sourceFiles = [fsrc]
      compileCoffee fsrc, fdest, options
        
      grunt.log.writeln "File " + fdest.green + " created."

    getSha1 files, pluck:'dest', key:'destSha1', (files)->
      json = {}
      for f in files
        json[f.src] = f.sha1
        json[f.dest] = f.destSha1
      try
        fs.writeFileSync options.json, JSON.stringify(json,null,''), 'utf8'
      catch e
        null

      done()





  compileCoffee = (srcFile, destFile, options) ->
    options = grunt.util._.extend(
      filename: srcFile
    , options)
    srcCode = grunt.file.read(srcFile)
    try
      compiled = require('../node_modules/coffee-script').compile(srcCode, options)
    catch e
      grunt.log.error e
      grunt.fail.warn "CoffeeScript failed to compile."

    if options.sourceMap
      grunt.file.write destFile, compiled.js
      grunt.file.write "#{destFile}.map", compiled.v3SourceMap
    else
      grunt.file.write destFile, compiled
      
      
      
