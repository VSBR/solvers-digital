var sass = require('./sass');
var fs = require('fs');

sass.builtIns = {
  image_size: function(param) {
    return '10px 10px';
  },
};

var css = sass.renderSync({file: 'test.scss'});
console.log(css);
