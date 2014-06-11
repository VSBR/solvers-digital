_ = require 'lodash'
Array::replace = ->
  s.replace.apply(s, arguments) for s in this

module.exports = (grunt) ->

  staticPath     = "../application/static"

  config =
    capture:
      website:
        root_top:                   '/m/'
        root_home:                  '/m/home/'
        guildbattle_index:          '/m/guildbattle/'
        guild_index:                '/m/guild/'
        guild_info_top:             '/m/guild/info/owner/'
        sham_guildbattle_index:     '/m/sham_guildbattle/'
        quest_index:                '/m/quest/'
        raid_index:                 '/m/raid/'
        ranking_index:              '/m/ranking/'
        g003_rarecoin_index:        '/m/gacha/g003_rarecoin/'
        g002_raidticket_index:      '/m/gacha/g002_raidticket/index/'
        g001_gachapoint_index:      '/m/gacha/g001_gachapoint/'
        compose_normal_base:        '/m/compose/normal/base/'
        compose_breakthrough_base:  '/m/compose/breakthrough/base/'
        deck_index:                 '/m/deck/'
        footballer_index:                 '/m/footballer/'
        footballer_sell_index:            '/m/footballer/sell/'
        footballer_history_index:         '/m/footballer_history/'
        job_rank_list:              '/m/job/list/0/'
        levelskilltree_index:       '/m/levelskilltree/'
        job_item_index:             '/m/job/item/'
        profile_index:              '/m/profile/'
        present_index:              '/m/present/'
        item_list:                  '/m/item/'
        shop_index:                 '/m/shop/'
        help_index:                 '/m/help/'
        theater_episode_index:      '/m/theater/1/'
        world_world_render:         '/m/world/world_root/index.html'
        configuration_index:        '/m/configuration/'


  require('./Gruntfile-js')(grunt, config)
  require('./Gruntfile-css')(grunt, config)

  require('./grunt-extension')(grunt)
  grunt.initConfig config

  #Load Plugin.
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-regarde'
  grunt.loadNpmTasks 'grunt-contrib-livereload'
  grunt.loadNpmTasks 'grunt-styleguide'
  grunt.loadNpmTasks 'grunt-csso'
  grunt.loadNpmTasks 'grunt-spritesmith'

  grunt.loadTasks "./grunt_tasks"

  #Default task.
  grunt.registerTask 'default', '変更を見張り、自動コンパイル', 'w'
  grunt.registerTask 'w', '変更を見張り、自動コンパイル', ['livereload-start', 'regarde']

  grunt.registerTask 'c', 'coffeeのコンパイルをするよ (DEBUG)', [
    'coffee',              # tmp/js にコンパイル
    'myCopy:pass',         # coffee/**/*.js を tmp/js にコピー
    'syncFiles:js',        # 要らん js を削除
    'commonjs-map:debug',  # requireモジュール使える形に tmp/js/**/*.js を package.js にパッキング
    'concat',              # back_door.js から back_door.html 作成
    'myCopy:static',       # static にコピー
    'growl:coffee'         # growl通知
  ]

  grunt.registerTask 'j', 'JavaScriptを結合をするよ (DEBUG)', ['concat:js', 'growl:js']

  grunt.registerTask 's', 'sassのコンパイルをするよ (DEBUG)', [
    'libsass:debug',     # scssコンパイル
    'growl:sass'         # growl通知
    'styleguide'
  ]

  grunt.registerTask 'd', 'sassコンパイル+ja結合をするよ (DEBUG)', ['s', 'j']

  grunt.registerTask 'l', 'lightpngで差分があったファイルを圧縮', ['lightpng']

  #release task.
  grunt.registerTask 'rc', 'coffeeのコンパイルをするよ (RELEASE)', [
    # 'clean:coffee'
    'coffee'
    'myCopy:pass'
    'syncFiles:js',      # 要らん js を削除
    'commonjs-map:release'
    'concat'
    'myCopy:static'
    'uglify'
    'growl:coffee'
  ]
  grunt.registerTask 'rj', 'JavaScriptを結合&ミニファイをするよ (RELEASE)', [
    'concat:js'
    'uglify'
    'growl:js'
  ]
  grunt.registerTask 'rs', 'sassのコンパイルをするよ (RELEASE)', [
    'checkConflict'
    'image-data' # 画像情報の取得・更新
    'mysprite'
    'resizeImage:normal'
    'image-data' # 画像情報の取得・更新
    'lightpng'
    'image-data' # 画像情報の取得・更新
    'libsass:release',     # scssコンパイル
    'growl:sass'
    'styleguide'
  ]

  grunt.registerTask 'styleguide', 'KSS · Knyle Style Sheets - Warpspire', [
    'concat:sass'
    'clean:kss'
    'kss'
    'replace'
    'growl:kss'
  ]

  grunt.registerTask 'r', 'sassコンパイル+js結合をするよ (DEBUG)', [
    'rs'
    'rj'
  ]
