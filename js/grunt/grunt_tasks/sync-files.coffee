#
# * sync-files
# * 一時ディレクトリ等に残った要らないファイルを削除する
# * 
# * @author okada
#

fs = require 'fs'
path = require "path"

existsSync = fs.existsSync || path.existsSync
mtime = (filepath)-> fs.statSync(filepath).mtime.getTime()

grunt = null
log = null
fail = null


TASK_NAME = 'syncFiles'
DESCRIPTION = '''
  リネーム等で一時ディレクトリ等に残った要らないファイルを削除する
'''
DEFAULT_OPTIONS =
  root: ['.']

_exports = (grunt) ->

  return unless grunt
  log = grunt.log.writeln.bind(grunt.log)
  fail = grunt.fail.warn.bind(grunt.fail)

  grunt.registerMultiTask TASK_NAME, DESCRIPTION, ->
    _done = this.async()
    done = ->
        grunt.log.ok()
        process.nextTick _done
    unless files = this.files.slice(0)
      fail 'require files:'
    options = this.options(DEFAULT_OPTIONS)
    try
      task grunt, files, options, log, fail, done
    catch e
      console.log e.stack
      fail e

  null


task = (grunt, files, options, log, fail, done)->

  dest_dict = {}
  for {dest} in files
    dest = [dest] unless dest instanceof Array
    for f in dest
      dest_dict[f] = 1

  unless options.root instanceof Array
    options.root = [options.root]

  for root in options.root
    all = grunt.file.expand path.join(root, '**/*.*')
    for f in all
      if dest_dict[f]
        delete dest_dict[f]
        #log "要る: #{f}"
      else
        log "要らん: #{f}"
        grunt.file.delete f, force: true

  for f of dest_dict
    log "足らん: #{f}"


  done()




module.exports = _exports
      
