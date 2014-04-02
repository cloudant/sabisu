module.exports = (grunt) ->

  require('load-grunt-tasks')(grunt)
  require('time-grunt')(grunt)

  gruntConfig =
    pkg: grunt.file.readJSON('package.json')

    yeoman:
      app: require('./bower.json').appPath || 'sabisu',
      dist: 'dist'

    open:
      dev:
        path: 'http://127.0.0.1:8080'

    coffee:
      options:
        join: true
      compile:
        files:
          'lib/sabisu/public/js/sabisu.js': ["lib/sabisu/public/coffee/sabisu.coffee", "lib/sabisu/public/coffee/*.coffee"]
 
    watch:
      coffee:
        files: ["lib/sabisu/public/coffee/sabisu.coffee", "lib/sabisu/public/coffee/*.coffee"]
        tasks: ["coffee"]
 
    coffeelint:
      sabisu: ["lib/sabisu/public/coffee/*.coffee"]
      options:
        no_trailing_whitespace:
          level: 'error'
 
    jsonlint:
      sabisu:
        src: [ 'config.demo.json', 'package.json', 'lib/sabisu/**/*.json' ]

    uglify:
      options:
        banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' +
                '<%= grunt.template.today("yyyy-mm-dd") %> */'
        compress:
          drop_console: true
          global_defs:
            'DEBUG': false
          dead_code: true
      sabisu:
        files:
          'lib/sabisu/public/js/sabisu.min.js': ['lib/sabisu/public/js/sabisu.js']

    csslint:
      lax:
        src: ['lib/sabisu/public/css/*.css', '!lib/sabisu/public/css/*.min.css', '!lib/sabisu/public/css/bootstrap.min.css']

    cssmin:
      options:
        banner: '/* My minified css file */'
      minify:
        expand: true
        cwd: 'lib/sabisu/public/css'
        src: ['*.css', '!*.min.css']
        dest: '.'
        ext: '.min.css'

  grunt.initConfig gruntConfig

  grunt.loadTasks 'tasks'
 
  grunt.registerTask 'default', 'lint'
  grunt.registerTask 'lint', ['coffeelint', 'jsonlint']
  grunt.registerTask 'min', ['uglify', 'cssmin']
