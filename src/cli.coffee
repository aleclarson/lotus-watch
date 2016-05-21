
# TODO: Only initialize modules when necessary (to speed up start-up time and avoid high memory consumption).
# TODO: Automated nightly commits. Exclude generated files.
# TODO: A command that lists the modules that have uncommitted changes.
# TODO: A command that lists the dependencies or dependers of each module.
# TODO: Notify when dependencies exist that aren't being used.

ErrorMap = require "ErrorMap"
inArray = require "in-array"
syncFs = require "io/sync"
Path = require "path"
sync = require "sync"
log = require "log"
Q = require "q"

module.exports = ->

  { Module } = lotus

  log.moat 1
  log.white "Crawling: "
  log.yellow lotus.path
  log.moat 1

  initModule = (mod) ->

    mod.load [ "config", "plugins" ]

    .fail (error) ->
      errors.load.resolve error, ->
        log.yellow mod.name

    .done()

  Module.watch lotus.path,

    add: (mod) ->
      initModule(mod).done()

    unlink: (mod) ->
      # TODO: Handle deleted modules!

    ready: (mods) ->

      log.moat 1
      if mods.length > 0
        log.white "Found #{log.color.green mods.length} modules: "
        log.moat 1
        log.plusIndent 2
        for module, index in mods
          color = if index % 2 then "cyan" else "green"
          newPart = module.name + " "
          newLength = log.line.length + newPart.length
          log.moat 0 if newLength > log.size[0] - log.indent
          log[color] newPart
        log.popIndent()
      else
        log.white "Found #{log.color.green.dim 0} modules!"

      Q.all sync.map mods, (mod) ->
        initModule mod

      .then ->
        log.moat 1
        log.gray "Watching files..."
        log.moat 1

  # Keep the process alive.
  return Q.defer().promise

errors =

  load: ErrorMap
    quiet: [
      "'package.json' could not be found!"
    ]
