
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
      if mods.length > 0
        log.white "Found #{log.color.green mods.length} modules: "
        log.moat 1
        log.plusIndent 2
        for module, index in mods
          color = if index % 2 then "cyan" else "green"
          newPart = module.name + " "
          newLength = log.line.length + newPart.length
          log.moat 0 if log.size and newLength > log.size[0] - log.indent
          log[color] newPart
        log.popIndent()
      else
        log.white "Found #{log.color.green.dim 0} modules!"

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
