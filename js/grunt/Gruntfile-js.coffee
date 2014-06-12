
{_rename} = require './grunt_tasks/lib/utils'
_ = require 'lodash'
staticPath     = "../../static"

module.exports = (grunt, config) ->

  _config =

    'commonjs-map':
      debug:
        options:
          target: 'debug'
          flags:
            __APP_NAME__: 'neopoodle'
            __DEBUG__: true
          main: './main'
          base: 'tmp/js/'
          sourceMap:
            sourceRoot: '/static'
        filesExt:
          flat: true
          sha1: true
          src: 'tmp/js/**/*.js'
          dest: 'tmp/package.js'
          ignore: [
            'tmp/js/back_door.js'
            'tmp/js/debug.js'
            'tmp/js/ex_admin.js'
            'tmp/js/views/nanaco/**/*.js'
          ]
      release:
        options:
          target: 'release'
          # flags: # uglifyの方で定義する
          #   __APP_NAME__: 'neopoodle'
          #   __DEBUG__: true
          main: './main'
          base: 'tmp/js/'
        filesExt:
          flat: true
          sha1: true
          src: 'tmp/js/**/*.js'
          dest: 'tmp/package.js'
          ignore: [
            'tmp/js/back_door.js'
            'tmp/js/debug.js'
            'tmp/js/ex_admin.js'
            'tmp/js/views/nanaco/**/*.js'
          ]

    concat:
      back_door:
        src: [
          'html/html_header.html'
          'tmp/js/back_door.js'
          'html/html_footer.html'
        ]
        dest: "tmp/html/back_door.html"
      ex_admin:
        src: [
          "tmp/js/views/ex_admin/*.js"
        ]
        dest: "tmp/js/ex_admin.js"
      js:
        src:[
          './js/lib/!(underscore)*.js'
          './js/root.js'
          './js/ui/**/*.js'
          './js/website/**/*.js'
          './js/execute.js'
        ]
        dest: "#{staticPath}/js/package.js"

    myCopy:
      pass: #JavaScriptをstatic/jsへコピー
        files:
          expand: true
          src: 'coffee/**/*.js'
          rename: -> @paths.s(0:'tmp/js') # @pathsはsrcの/区切りパス, 0番目を'tmp/js'に置き換えてjoin

      'static':
        files: [
            src: "tmp/js/ex_admin.js"
            dest: "#{staticPath}/js/ex_admin.js"
          ,
            src: "tmp/package.js"
            dest: "#{staticPath}/js/package.js"
          ,
            src: "tmp/package.js.map"
            dest: "#{staticPath}/js/package.js.map"
        ]

    uglify:
      options:
        compress: # https://github.com/mishoo/UglifyJS2 Compressoroptions参照
          unsafe: true
          conditionals: true
          hoist_vars: true
          comparisons: true
          warnings: false
          global_defs:
            __APP_NAME__: 'neopoodle'
            __DEBUG__: false
      build:
        files:
          src: "../../static/js/package.js"
          dest: "../../static/js/package.js"

    growl:
#      coffee:
#        message: "coffeeｺﾝﾊﾟｲﾙｵﾜﾀ＼(^o^)／"
      js:
        message: "js結合ｵﾜﾀ＼(^o^)／"

    clean:
      coffee: [
        'tmp/js'
        'tmp/html'
      ]

  _.merge config, _config


