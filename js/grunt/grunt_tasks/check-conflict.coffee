fs = require 'fs'
path = require 'path'
{growl} = try require './growl'

_exports = (grunt) ->

  return unless grunt

  grunt.registerMultiTask "checkConflict", "コンフリクトがないかチェック", ->
    
    options = this.options(
      msg: 'conflict!! <%=src%>'
    )
    _ = grunt.util._
    msg = options.msg

    for ff in @files
      for f in ff.src
        
        code = grunt.file.read(f)

        if code.match(/[\r\n](<<<<<<<|>>>>>>>|=======)\s/)

          param = 
            src: path.relative('.', f)

          errmsg = _.template(msg, param, {interpolate : /(?:\{\{|<%=)([\s\S]+?)(?:\}\}|%>)/g})
          growl(errmsg) if growl
          grunt.fail.warn errmsg

    grunt.log.ok()


module.exports = _exports
      
      
