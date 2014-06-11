
var _exports = function (grunt){

  if (!grunt) return null;
  var skip = false;
  // growlで通知
  grunt.registerMultiTask('growl', 'growlで通知', function() {
    var msg = this.data.message || this.data;
    skip = true;
    if (grunt.regarde&&grunt.regarde.growl) {
      growl(grunt.regarde.growl);
      grunt.regarde.growl = false;
    } else {
      growl(msg);
    }
    grunt.log.writeln('growl: ' + msg);
    skip = false;
  });

  var origin = grunt.fail.warn;
  grunt.fail.warn = function(e, errcode) {
    if (!skip) {
      var message = typeof e === 'string' ? e : e.message;
      message = message + '';
      console.log(message.red);
      growl('Aborted due to warnings.\n--\n'+message);
    }
    return origin.apply(this, arguments);
  };
};

var growl = function(msg) {
  msg = msg || 'no message';
  msg = msg.replace(/"/g, '\\"');
  var spawn = require('child_process').spawn;
  child = spawn('osascript');
  child.stdin.write([
    'tell application "System Events"',
    '    set isRunning to (count of (every process whose bundle identifier is "com.Growl.GrowlHelperApp")) > 0',
    'end tell',
    '',
    'if isRunning then',
    '    tell application id "com.Growl.GrowlHelperApp"',
    '        set the allNotificationsList to {"Test Notification", "Another Test Notification"}',
    '        set the enabledNotificationsList to {"Test Notification"}',
    '        register as application "Growl AppleScript Sample" all notifications allNotificationsList default notifications enabledNotificationsList icon of application "Script Editor"',
    '        ',
    '        notify with name "Test Notification" title "grunt" description "' + msg + '" application name "Growl AppleScript Sample"',
    '    end tell',
    'end if'
  ].join('\n'));
  child.stdin.end();
};

_exports.growl = growl;
module.exports = _exports;