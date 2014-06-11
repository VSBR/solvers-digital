module.exports = function (grunt){
	
  //超テキトー
  grunt.registerMultiTask('exec', 'child_process.exec', function() {
    var exec = require('child_process').exec;
    var path = require('path');
    var done = this.async();
    var files = grunt.file.expandFiles(this.data.files || this.data);
    //var dests = grunt.file.expandFiles(this.dest);
    if (files && files.length > 0) {
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        var name = path.basename(file);
        var command = this.data.command.replace(/\[src\]/g, file).replace(/\[name\]/g, name);
        exec(command, {cwd:this.data.cwd || null}, function(error, stdout, stderr) {
        });
        grunt.log.writeln('exec `' + command + '`');
      }
    } else {
        var command = this.data.command;
      exec(command, {cwd:this.data.cwd || null}, function(error, stdout, stderr) {
        grunt.log.writeln('stdout>\n' + stdout);
        grunt.log.writeln('stderr>\n' + stderr);
      });
      grunt.log.writeln('exec `' + command + '`');
    }
  });
};