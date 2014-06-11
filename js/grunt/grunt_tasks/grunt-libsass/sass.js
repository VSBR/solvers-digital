var binding;
var fs = require('fs');
try {
  if (fs.realpathSync(__dirname + '/build')) {
    // use the build version if it exists
    binding = require(__dirname + '/build/Release/binding');
  }
} catch (e) {
  // default to a precompiled binary if no build exists
  // var platform_full = process.platform+'-'+process.arch;
  // binding = require(__dirname + '/precompiled/'+platform_full+'/binding');
}
if (binding == null) {
  throw new Error('Cannot find appropriate binary library for node-sass');
}

var SASS_OUTPUT_STYLE = {
    nested: 0,
    expanded: 1,
    compact: 2,
    compressed: 3
};

var SASS_SOURCE_COMMENTS = {
  none: 0,
  // This is called default in libsass, but is a reserved keyword here
  normal: 1,
  map: 2
};

var prepareOptions = function(options) {
  var paths, style;
  var options = typeof options !== 'object' ? {} : options;
  var paths = options.include_paths || options.includePaths || [];
  var style = SASS_OUTPUT_STYLE[options.output_style || options.outputStyle] || 0;
  var comments = SASS_SOURCE_COMMENTS[options.source_comments || options.sourceComments] || 0;

  return {
    paths: paths,
    style: style,
    comments: comments
  };
};

exports.builtIns = {};
var _builtIns = {};

var callbackBuiltInFunctions = function(name, param) {
  var func;
  if (func  = _builtIns[name]) {
    try {
      var result = func(param);
    } catch(e) {
      console.log(e.stack);
      return '::Error: built-in function `'+name+'`::';
    }
    return result || 'null';
  }
  throw new Error('built-in function "'+name+'" is invalid');
};


exports.renderSync = function(options) {
  var newOptions;

  if (typeof arguments[0] === 'string') {
    return deprecatedRenderSync.apply(this, arguments);
  }

  newOptions = prepareOptions(options);

  if (options.file == null) {
    throw new Error('require option.file');
  }

  // register built-in functions
  var builtInNames = [];
  _builtIns = {};
  var has = ({}).hasOwnProperty;
  for (var name in exports.builtIns) {
    if (has.call(exports.builtIns, name)) {
      var f = exports.builtIns[name];
      if (typeof f === 'function') {
        name = name.replace(/_/g,'-');
        _builtIns[name] = f;
        builtInNames.push(name);
      }
    }
  }

  //Assume data is present if file is not. binding/libsass will tell the user otherwise!
  return binding.renderFileSync(
    options.file,
    newOptions.paths.join(":"),
    newOptions.style,
    newOptions.comments,
    callbackBuiltInFunctions,
    builtInNames);
};

exports.middleware = require('./lib/middleware');
exports.cli = require('./lib/cli');
