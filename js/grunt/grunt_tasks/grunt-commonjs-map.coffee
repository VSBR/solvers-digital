
# CommonJS っぽい事ができるようにcoffeeを結合する

sourceLib = """

var global = (function(){return this})();
var require = function (path, base) {

  var sep = '/', paths = path.split(sep), resolved = [], name, p, dir, module, requireRel;

  if (base) {
    if (typeof base == 'string')
      base = base.split(sep);
    if (base instanceof Array)
      paths = base.concat(paths);
    else
      throw new Error('require error: base is invalid');
  }
  
  for (var i=0,len = paths.length; i < len; i++ ) {
    p = paths[i];
    if (p === '.' && i > 0)
      continue;
    else if (p === '..'){
      resolved.pop();
      resolved.length === 0 && resolved.push('.');
    } else
      resolved.push(p);
  }
  name = resolved.join(sep);
  
  if (module = _module[name]) {
    return module.exports;
  } else if (module === null) {
    throw new Error(name+': circular required!!');
  } else if (define = require.define[name]) {
    dir = resolved.slice(0,-1);
    requireRel = _require[dir] || function(rel,abs){return require(rel,abs||dir);};
    _require[dir] = requireRel;
    module = {exports:{}, require:requireRel};
    _module[name] = null;
    define.call(module.exports, module.exports, module, requireRel);
    _module[name] = module;
    return module.exports;
  }
  throw new Error(name+': cant find module');
};
var _define = require.define = {},
  _module = require.module = {},
  _require = {};
global.require = require;

"""

sourceMap = require 'source-map'
fs = require 'fs'
path = require 'path'
{getSha1} = require './lib/utils'

readSourceMap = (mapFilename) ->

  if not fs.existsSync mapFilename
    throw new Error "#{mapFilename}: No such source map file"

  mapFileContents = fs.readFileSync mapFilename, 'utf8'

  try
    map = JSON.parse mapFileContents
  catch error
    throw new Error "#{mapFilename}: Invalid JSON"

  consumer = new sourceMap.SourceMapConsumer map

  return consumer

module.exports = (grunt) ->
  
  fs = require 'fs'
  
  grunt.registerMultiTask "commonjs-map", "CmmonJS使えるようにJSをパッケージングする", ->
    
    files = @files
    options = this.options(
      json: 'tmp/commonjs-map.json'
    )
    base = options.base
    
    source = ''

    if files.length == 0
      grunt.log.warn "error: files.length === 0."
      return
    
    dests = {}
    for f in @files
      dests[f.dest] = 1
    dests = Object.keys(dests)
    if dests.length != 1
      console.log dests
      grunt.log.warn "error: dest must be only one file."
      return
    dest = dests[0]

    # isSkip?
    json = try
      JSON.parse(fs.readFileSync(options.json, 'utf8'))
    catch e
      {}
    isSkip = do ->
      if json['!!target!!'] != options.target
        return false
      for f in files
        if json[f.src] != f.sha1
          return false
        if json[dest] != f.destSha1
          return false
      return true
    # if isSkip
    #   grunt.log.writeln "all files not changed. skipped.".green
    #   return

    if options.sourceMap
      fname = dest.replace(/^.*\//,'')
      generated = new sourceMap.SourceMapGenerator(
        file: fname
      )
      #source += "//@ sourceMappingURL=#{fname}.map?t=#{Date.now()}\n"
      source += "//@ sourceMappingURL=#{fname}.map\n"
    
    source += "(function(){\n\n"
    source += "#{sourceLib}\n"

    for f in files
      
      fpath = f.src

      srcCode = grunt.file.read(fpath)
      relpath = fpath.replace(base, './').replace(/\.js$/,'')
      
      source += "\n_define['#{relpath}'] = function(exports, module, require){\n  /* ------------------------------ */\n"
      lineNum = (source.match(/\n/g) || []).length - 1
      source += srcCode
      source += "\n  /* ------------------------------ */\n  return exports;\n};\n\n"
      grunt.log.writeln "File #{fpath.cyan} pack."
      
      if options.sourceMap
        mapFilename = "#{fpath}.map"
        if not fs.existsSync mapFilename
          continue
        original = readSourceMap "#{fpath}.map"
        original.eachMapping (mapping) ->
          #console.log lineNum + mapping.generatedLine, mapping.originalLine
          if sourceRoot = options.sourceMap.sourceRoot
            originFile = path.join sourceRoot, mapping.source
          else
            originFile = mapping.source
          generated.addMapping(
            generated:
              line: lineNum + mapping.generatedLine
              column: mapping.generatedColumn
            original:
              line: mapping.originalLine
              column: mapping.originalColumn
            source: originFile  # Original source file
          )
        
      
  
    for own k,v of options.flags
      if typeof v == 'string'
        v = "'#{v}'"
      source += "var #{k} = #{v};\n"
    
    if options.main
      source += "\n\nrequire('#{options.main}');\n\n"

    source += "})();\n\n"
  
    if options.sourceMap
      grunt.file.write dest, source
      grunt.file.write "#{dest}.map", generated.toString()
    else
      grunt.file.write dest, source
    
    done = this.async()
    getSha1 [dest], (hash)->
      json = {'!!target!!': options.target}
      for f in files
        json[f.src] = f.sha1
      json[dest] = hash[dest]
      try
        fs.writeFileSync options.json, JSON.stringify(json,null,''), 'utf8'
      catch e
        null

      done()
    
    
    