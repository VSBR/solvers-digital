module.exports = function(grunt) {
  'use strict';

  // TODO: ditch this when grunt v0.4 is released
  grunt.util = grunt.util || grunt.utils;

  grunt.registerMultiTask('docco', 'CoffeeScript doc generator', function() {
    var path = require('path');

    var helpers = require('./lib-contrib').init(grunt);

    var options = helpers.options(this, {
      bare: false,
      basePath: false,
      flatten: false
    });

    grunt.verbose.writeflags(options, 'Options');

    // TODO: ditch this when grunt v0.4 is released
    this.files = this.files || helpers.normalizeMultiTaskFiles(this.data, this.target);

    var basePath;
    var newFileDest;

    var srcFiles;
    var srcCompiled;
    var taskOutput;

    this.files.forEach(function(file) {
      file.dest = path.normalize(file.dest);
			var destDir = path.resolve('.', file.dest);
      srcFiles = grunt.file.expandFiles(file.src);

      if (srcFiles.length === 0) {
        grunt.log.writeln('Unable to compile; no valid source files were found.');
        return;
      }
			
      srcFiles.forEach(function(srcFile) {
				srcFile = path.resolve('.', srcFile);
				run(srcFile, destDir);
      });

    });
  });

  var run = function(srcFile, destDir) {
    var exec = require('child_process').exec;
    try {
      exec('docco/docco '+srcFile+' -o '+destDir, function(){});
			grunt.log.writeln('docco ' + srcFile);
    } catch (e) {
      grunt.log.error(e);
      grunt.fail.warn('docco error.');
    }
  };
};
