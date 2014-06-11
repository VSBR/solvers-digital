#
# * filter-copy.coffee
# * 条件コピー
# * 
# * @author okada
# 

fs = require 'fs'

module.exports = (grunt) ->

  path = require("path")

  grunt.registerMultiTask "filterCopy", "Copy files.", ->
    kindOf = grunt.util.kindOf
    options = @options(
      processContent: false
      processContentExclude: []
      filter: null
    )
    copyOptions =
      process: options.processContent
      noProcess: options.processContentExclude

    grunt.verbose.writeflags options, "Options"
    dest = undefined
    isExpandedPair = undefined
    @files.forEach (filePair) ->
      isExpandedPair = filePair.orig.expand or false
      filePair.src.forEach (src) ->

        if detectDestType(filePair.dest) is "directory"
          dest = (if (isExpandedPair) then filePair.dest else unixifyPath(path.join(filePair.dest, src)))
        else
          dest = filePair.dest

        if typeof options.filter == 'function'
          mtimeSrc  = if grunt.file.exists(src)
            fs.statSync(src).mtime.getTime()
          else
            null
          mtimeDest = if grunt.file.exists(dest)
            fs.statSync(dest).mtime.getTime()
          else
            null

          if not options.filter.call(null, param = {src, dest, options, mtimeSrc, mtimeDest})
            grunt.log.writeln "skipped " + dest.cyan
            return
          {src, dest} = param

        if grunt.file.isDir(src)
          grunt.log.writeln "Creating " + dest.cyan
          grunt.file.mkdir dest
        else
          grunt.log.writeln "Copying " + src.cyan + " -> " + dest.cyan
          grunt.file.copy src, dest, copyOptions



  detectDestType = (dest) ->
    if grunt.util._.endsWith(dest, "/")
      "directory"
    else
      "file"

  unixifyPath = (filepath) ->
    if process.platform is "win32"
      filepath.replace /\\/g, "/"
    else
      filepath
