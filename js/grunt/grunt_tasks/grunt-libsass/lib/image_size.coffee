fs = require 'fs'

cache = {}

exports.get = (filename)->
  if data = cache[filename]
    return data
  ext = filename.split(/\./)
  ext = ext[ext.length-1].toLowerCase()

  try
    if fs.existsSync(filename)
      fd = fs.openSync(filename, 'r')

      func = reader[ext]
      if func and data = func(fd)
        cache[filename] = data
      else
        console.log "#{filename} サイズ取得ができません"
        data = {w:0, h:0}
      fs.closeSync(fd)
    else
      console.log "#{filename} is not exists"
      data = {w:0, h:0}
  catch e
    console.log "#{filename} 開けない"
    data = {w:0, h:0}
  data


reader =
  png: (fd)->
    buf = new Buffer(8)
    b = fs.readSync(fd, buf, 0, 8, 8+4+4)
    if b == 8
      w = (buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | (buf[3])
      h = (buf[4] << 24) | (buf[5] << 16) | (buf[6] << 8) | (buf[7])
      return {w,h}
    null

  gif: (fd)->
    # http://www.tohoho-web.com/wwwgif.htm
    buf = new Buffer(4)
    b = fs.readSync(fd, buf, 0, 4, 3+3)
    if b == 4
      w = (buf[0] << 8) | (buf[1])
      h = (buf[2] << 8) | (buf[3])
      return {w,h}
    null

  jpg: (fd)->
    # http://sadoyama.sakura.ne.jp/world/htm/note/002_02_jpg.htm#code
    buf = new Buffer(4)
    pos = 2
    while 1
      b = fs.readSync(fd, buf, 0, 4, pos)
      return if b != 4
      mark = (buf[0] << 8) | buf[1]
      # console.log(mark.toString(16))
      size = (buf[2] << 8) | buf[3]
      if 0xffc0 <= mark <= 0xffcf
        b = fs.readSync(fd, buf, 0, 4, pos+5)
        return if b != 4
        h = (buf[0] << 8) | buf[1]
        w = (buf[2] << 8) | buf[3]
        return {w, h}
      if mark == 0xffd9
        break
      pos += size + 2
    null

reader.jpeg = reader.jpg

