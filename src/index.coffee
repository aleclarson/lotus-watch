
exports.initCommands = ->

  watch: -> require "./cli"

exports.initModuleType = ->
  require "./Module"

exports.initFileType = ->
  require "./File"
