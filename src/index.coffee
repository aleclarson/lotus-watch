
module.exports =
  loadGlobals: -> require "./global"
  loadCommands: -> require "./cli"
  loadModuleMixin: -> require "./Module"
