
# TODO: Only initialize modules when necessary (to speed up start-up time and avoid high memory consumption).
# TODO: Automated nightly commits. Exclude generated files.
# TODO: Notify when dependencies exist that aren't being used.

exports.watch = ->

  log.moat 1
  log.white "Crawling: "
  log.yellow lotus.path
  log.moat 1

  watcher = lotus.watchModules lotus.path

  watcher.on "add", (mod) ->
    mod.load ["config", "plugins"]
    .fail errors.loadModule

  watcher.on "unlink", (mod) ->
    # TODO: Handle deleted modules!
    log.warn "Module was deleted, but went unhandled: '#{mod.path}'"

  watcher.on "ready", (mods) ->

    {green} = log.color
    log.moat 1
    log.white "Found #{green mods.length} modules!"
    log.moat 1

    Promise.all mods, (mod) ->
      mod.load ["config", "plugins"]
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
