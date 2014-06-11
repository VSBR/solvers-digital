spritesmith = require("spritesmith")
# json2css = require("json2css")
_ = require("underscore")
fs = require("fs")
path = require("path")
#url = require("url2")
{exec} = require 'child_process'
{getSha1} = require './lib/utils'

_relpath = (base, target, abs=false)->
  base = fs.realpathSync(base).split(path.sep)
  target = fs.realpathSync(target).split(path.sep)
  min = Math.min(base.length, target.length)
  for i in [0...min]
    if base[0] == target[0]
      base.shift()
      target.shift()
  if abs
    if base.length > 0
      console.log 'basepath is not ancestors of targetpath'
      for b in base
        target.unshift '..'
    else
      target.unshift ''
  else
    for b in base
      target.unshift '..'
  target.join(path.sep)


class ExtFormat
  constructor: ->
    @formatObj = {}

  add: (name, val) ->
    @formatObj[name] = val

  get: (filepath) ->
    
    # Grab the extension from the filepath
    ext = path.extname(filepath)
    lowerExt = ext.toLowerCase()
    
    # Look up the file extenion from our format object
    formatObj = @formatObj
    format = formatObj[lowerExt]
    format


# Create img and css formats
imgFormats = new ExtFormat()
cssFormats = new ExtFormat()

# Add our img formats
imgFormats.add ".png", "png"
imgFormats.add ".jpg", "jpeg"
imgFormats.add ".jpeg", "jpeg"

# Add our css formats
cssFormats.add ".styl", "stylus"
cssFormats.add ".stylus", "stylus"
cssFormats.add ".sass", "sass"
cssFormats.add ".scss", "scss"
cssFormats.add ".less", "less"
cssFormats.add ".json", "json"
cssFormats.add ".css", "css"

module.exports = (grunt) ->
  
  grunt.sprite = {srcs:{}, dests:{}, updates:{}}
  # Create a SpriteMaker function
  SpriteMaker = ->
    data = @data
    src = data.src
    destImg = data.destImg
    destCSS = data.destCSS
    that = this
    
    # Verify all properties are here
    return grunt.fatal("grunt.sprite requires a src, destImg, and destCSS property")  if not src or not destImg or not destCSS
    
    # Load in all images from the src
    srcFiles = grunt.file.expand(src)
    if srcFiles.length == 0
      throw new Error 'src is empty'

    # Create an async callback
    cb = @async()
    
    # Determine the format of the image
    imgOpts = data.imgOpts or {}
    imgFormat = imgOpts.format or imgFormats.get(destImg) or "png"
    
    # Set up the defautls for imgOpts
    _.defaults imgOpts,
      format: imgFormat

    
    # Run through spritesmith
    opts = this.options()
    spritesmithParams =
      src: srcFiles
      engine: data.engine or opts.engine or "auto"
      algorithm: data.algorithm or opts.algorithm or "top-down"
      padding: data.padding or opts.padding or 0
      engineOpts: data.engineOpts or opts.engineOpts or {}
      exportOpts: imgOpts or opts.imgOpts

    rootPath = opts.rootPath or ''


    # ---------------------------------------------
    imageData = opts.imageData
    if typeof imageData == 'function'
      imageData = imageData()
    if typeof imageData == 'string'
      imageData = try
        JSON.parse(fs.readFileSync(imageData, 'utf8'))
      catch e
        {}
    imageData or= {}

    # ---------------------------------------------
    # skip判定
    isSkip = do ->
      if not fs.existsSync(destCSS) # json無い
        return false
      if not fs.existsSync(destImg) # sprite無い
        return false
      try
        text = fs.readFileSync(destCSS, 'utf8')
        json = JSON.parse(text)
      catch e
        return false
      tmp = {}
      for src in srcFiles
        name = _relpath(rootPath, src, true)
        sha1 = imageData[name].sha1
        tmp[name] = sha1
        grunt.sprite.srcs[name] = sha1
      for key,val of json
        if not tmp[key] # 前回存在したファイルが今回は無い
          return false
        if val.sha1 != tmp[key] # sha1が違うので変更あり
          return false
        grunt.sprite.dests[val.image] = val.image_sha1
        image_sha1 = val.image_sha1
        delete tmp[key]
      if Object.keys(tmp).length > 0 # 今回ファイルが増えてる
        return false
      name = _relpath(rootPath, destImg, true)
      unless imageData[name]
        return false
      if imageData[name].sha1 != image_sha1 # 出力ファイルが前回と違う
        return false
      return true 

    if isSkip
      grunt.log.writeln "srcFiles are not changed. skiped."
      cb true
      return

    grunt.imageData?.changed = true

    spritesmith spritesmithParams, (err, result) ->
      
      # If an error occurred, callback with it
      if err
        grunt.fatal err
        return cb(err)
      
      # Otherwise, write out the result to destImg
      destImgDir = path.dirname(destImg)
      grunt.file.mkdir destImgDir
      fs.writeFileSync destImg, result.image, "binary"
      
      # Generate a listing of CSS variables
      coordinates = result.coordinates
      properties = result.properties
      spritePath = destImg
      if rootPath
        spritePath = _relpath(rootPath, destImg, true)

      cleanCoords = {}

      # Clean up the file name of the file
      Object.getOwnPropertyNames(coordinates).sort().forEach (file) ->
        
        if rootPath
          name = _relpath(rootPath, file, true)
        else
          # Extract the image name (exlcuding extension)
          fullname = path.basename(file)
          nameParts = fullname.split(".")
          
          # If there is are more than 2 parts, pop the last one
          nameParts.pop()  if nameParts.length >= 2
          
          # Extract out our name
          name = nameParts.join(".")
        coords = coordinates[file]
        
        # Specify the image for the sprite
        # coords.name = name
        coords.image = spritePath
        coords.total_width = properties.width
        coords.total_height = properties.height
        if idata = imageData[name]
          coords.sha1 = idata.sha1
          grunt.sprite.srcs[name] = idata.sha1
        cleanCoords[name] = coords
        # Save the cleaned name and coordinates
        # cleanCoords.push coords

      writeCSS = ->
        getSha1 [destImg], (hash)->
          # dest sha1
          sha1 = hash[destImg]
          console.log 'sha1: '+sha1
          for key,val of cleanCoords
            destImgVal = val.image
            val.image_sha1 = sha1
          # Render the variables via json2css
          cssFormat = "json"
          cssStr = JSON.stringify(cleanCoords, null, '  ')
          
          # Write it out to the CSS file
          destCSSDir = path.dirname(destCSS)
          grunt.file.mkdir destCSSDir
          fs.writeFileSync destCSS, cssStr, "utf8"

          # 他タスクで image_sha1 を変更した場合のための更新処理
          update_func = do (cleanCoords, destCSS)-> (_sha1)->
            for own src,data of cleanCoords
              data.image_sha1 = _sha1
            cssStr = JSON.stringify(cleanCoords, null, '  ')
            fs.writeFileSync destCSS, cssStr, "utf8"
            console.log 'update: '+destCSS
          grunt.sprite.dests[destImgVal] = sha1
          grunt.sprite.updates[destImgVal] = update_func

          done()
      
      done = ->
        grunt.log.writeln "Files \"" + destCSS + "\", \"" + destImg + "\" created."
        # Callback
        cb true

      # Fail task if errors were logged.
      return cb false  if that.errorCount

      if typeof opts.optimize == 'string'
        cmd = opts.optimize.replace(/{}/g, destImg)
        fname = destImg.split(path.sep)[-1...][0]
        grunt.log.writeln "optimizing \"" + fname + "\" ..."
        exec cmd, (err, stdout, stderr)->
          if err
            return cb false
          writeCSS()
      else
        writeCSS()

  
  # Export the SpriteMaker function
  grunt.registerMultiTask "mysprite", "Spritesheet making utility", SpriteMaker
