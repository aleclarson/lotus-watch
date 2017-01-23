
# TODO: Only initialize modules when necessary (to speed up start-up time and avoid high memory consumption).
# TODO: Automated nightly commits. Exclude generated files.
# TODO: A command that lists the modules that have uncommitted changes.
# TODO: A command that lists the dependencies or dependers of each module.
# TODO: Notify when dependencies exist that aren't being used.

module.exports = ->

  {Module} = lotus

  log.moat 1
  log.white "Crawling: "
  log.yellow lotus.path
  log.moat 1

  Module.watch lotus.path,

    add: (mod) ->
      mod.load [ "config", "plugins" ]
      .fail errors.loadModule

    unlink: (mod) ->
      # TODO: Handle deleted modules!

    ready: (mods) ->

      log.moat 1
      log.white "Found #{log.color.green mods.length} modules!"
      log.moat 1

      Promise.all mods, (mod) ->
        mod.load [ "config", "plugins" ]
        .fail errors.loadModule

      .then ->
        log.moat 1
        log.gray "Watching files..."
        log.moat 1

  # Keep the process alive.
  Promise.defer().promise

errors = {}
errors.loadModule = (error) ->
  return if /^Missing config file:/.test error.message
  throw error
