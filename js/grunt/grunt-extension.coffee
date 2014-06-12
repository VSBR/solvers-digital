_ = require 'lodash'
{expand} = require './grunt_tasks/lib/utils'

module.exports = (grunt)->

  # configをhookできるように
  configHooks = []
  do ->
    orig = grunt.initConfig
    grunt.initConfig = (config)->
      for hook in configHooks
        config = hook(config)
      orig(config)

  # __base__ targetがある場合他のtargetにmergeする
  do ->
    configHooks.push (config)->
      for own task, conf of config
        if base = conf.__base__
          delete conf.__base__
        for own name, data of conf when name != 'options'
          if base
            if typeof base == 'function'
              _.merge data, base(data, name, conf)
            else
              _.merge data, base
      config

  # files.renameがある場合、expand:trueを付け、配列に
  # さらにrenameのthisを便利に
  do ->
    _decorate_rename = (func)->
      fs = require 'fs'
      path = require 'path'
      if func._origin and func._decorator == arguments.callee
        return func
      deco = (dest, src)->
        paths = src.split(path.sep)
        dirs = paths[...-1]
        name = paths[-1...][0]
        chunks = name.split(/\./)
        paths.toString = paths.s = dirs.toString = dirs.s = (i,j)->
          if typeof i == 'number'
            return this.slice(i,j).join(path.sep)
          if typeof i == 'object'
            copied = this.slice()
            for own k,v of i
              copied[k] = v
            return copied.join(path.sep)
          return this.join(path.sep)
        obj =
          src: src,
          dest: dest
          sep: path.sep
          paths: paths
          dirs: dirs
          dir: dirs.join(path.sep)
          name: name
          base: chunks[...-1].join('.')
          ext: if chunks.length > 0 then '.'+chunks[-1...][0] else ''
          slice: (i,j)-> dirs.slice(i,j).join(path.sep)
          replace: (from,to)->
            if (i = src.indexOf(from)) > -1
              return src[..i]+to+src[i+from.length...]
            src
        func.apply(obj, arguments)
      deco._origin = func
      deco._decorator = arguments.callee
      deco

    configHooks.push (config)->
      for own task, conf of config
        for own name, data of conf when name != 'options'
          # files: expand: true を追加
          if f = data.filesExt
            if not Array.isArray(f) and f.src
              data.filesExt = [f]
            for f in data.filesExt when f.rename
              f.rename = _decorate_rename(f.rename)
              unless 'expand' of f
                f.expand = true
          if f = data.files
            if not Array.isArray(f) and f.src
              data.files = [f]
            for f in data.files when f.rename
              f.rename = _decorate_rename(f.rename)
      config

  # data.filesの展開を高機能・高速化
  do ->
    task = grunt.task
    normalize = task.normalizeMultiTaskFiles
    #this.files = task.normalizeMultiTaskFiles(this.data, target);
    # task.normalizeMultiTaskFiles = (data, target)->
    #   files = data.files
    #   if not files and Array.isArray(data)
    #     orig = data
    #     files = [{src:orig, dest:target, orig:orig}]
    #     data.files = files
    #   if not files
    #     data.files = files = []
    #   if not Array.isArray(files)
    #     data.files = files = [files]
    #   # console.log files
    #   files
    register = task.registerMultiTask
    task.registerMultiTask = (name, info, _fn)->
      if typeof info == 'function'
        fn = info
        info = 'task'
      else
        fn = _fn
      hooked = ->
        self = this
        done = self.async()
        args = arguments
        async = false
        this.async = ->
          async = true
          -> done.apply(self, arguments)
        filesExt = this.data.filesExt
        task = ->
          ret = fn.apply(self, args)
          if not async
            done()
        if filesExt
          expand this.data, (files)->
            self.files = files
            task()
        else
          self.files = normalize self.data, ''
          task()
        null
      register name, info, hooked
    grunt.registerMultiTask = task.registerMultiTask




  null