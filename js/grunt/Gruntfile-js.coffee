
{_rename} = require './grunt_tasks/lib/utils'
_ = require 'lodash'
staticPath     = "../../static"

module.exports = (grunt, config) ->

  _config =

    concat:
      js:
        src:[
          '../lib/*.js'
          '../controll/root.js'
          '../controll/gameData.js'
          '../ui/*.js'
          '../scene/*.js'
          '../controll/execute.js'
        ]
        dest: "#{staticPath}/js/package.js"

    uglify:
      options:
        compress: # https://github.com/mishoo/UglifyJS2 Compressoroptions参照
          unsafe: true
          conditionals: true
          hoist_vars: true
          comparisons: true
          warnings: false
          global_defs:
            __APP_NAME__: 'solvers'
            __DEBUG__: false
      build:
        files:
          src: "../../static/js/package.js"
          dest: "../../static/js/package.js"

    growl:
      js:
        message: "js結合ｵﾜﾀ＼(^o^)／"

  _.merge config, _config
