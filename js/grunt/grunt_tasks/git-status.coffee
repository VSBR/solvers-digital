#
# * git-status.coffee
# * git status -s を実行しjson出力
# * 
# * @author okada
# 
fs = require 'fs'

_exports = (grunt) ->

  return unless grunt

  gf = grunt.file

  grunt.registerMultiTask "gitStatus", "git status -s を実行しjson出力", ->
    
    done = this.async()
    dest = this.options(
      file: 'tmp/git-status.json'
    ).file
    cosole.log 'dest', dest
    _exports.get dest, -> done()

_exports.get = (dest, callback)->

  dest or= 'tmp/git-status.json'
  _exports._dest = dest
  console.log 'git status >', dest

  require('child_process').exec 'git status -s', (err, stdout)->
    
    status = null

    if stdout and not err
      status = {}
      for ln in stdout.split(/\n/) when ln = ln.trim()
        [st, f] = ln.split(/\s+/)
        status[f] = st

      fs.writeFileSync dest, JSON.stringify(status, null, 2)
      _exports._status = status

    callback(status)
  
_exports.last = (callback)->
  try
    status = _exports._status or JSON.parse fs.readFileSync(_exports._dest)
    process.nextTick -> callback(status)
  catch err
    _exports.get null, callback
  

module.exports = _exports