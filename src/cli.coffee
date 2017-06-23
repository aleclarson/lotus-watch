
# TODO: Only initialize modules when necessary (to speed up start-up time and avoid high memory consumption).
# TODO: Automated nightly commits. Exclude generated files.
# TODO: Notify when dependencies exist that aren't being used.

path = require "path"
fs = require "fsx"

exports.watch = (args) ->

  log.moat 1
  log.gray "Crawling..."
  log.moat 1

  dirs = args._
  unless dirs.length
    dirs.push lotus.path

  Promise.all dirs, (dir) ->
    dir = path.resolve dir
    throw Error "Path must be a directory!" unless fs.isDir dir
    configPath = path.join dir, "package.json"
    if fs.isFile configPath
    then watchModule dir
    else watchModules dir

  .then ->
    {green} = log.color
    log.moat 1
    log.white "Found #{green lotus.modules.length} modules!"
    log.moat 1

  # Keep the process alive.
  Promise.defer().promise

watchModule = (dir) ->
  mod = lotus.modules.load dir
  mod.load ["config", "plugins"]
  .fail errors.loadModule

watchModules = (dir) ->

  deferred = Promise.defer()

  watcher = lotus.watchModules dir

  watcher.on "add", (mod) ->
    mod.load ["config", "plugins"]
    .fail errors.loadModule

  watcher.on "unlink", (mod) ->
    # TODO: Handle deleted modules!
    log.warn "Module was deleted, but went unhandled: '#{mod.path}'"

  watcher.on "ready", (mods) ->

    Promise.all mods, (mod) ->
      mod.load ["config", "plugins"]
      .fail errors.loadModule

    .then deferred.resolve
    .fail deferred.reject

  return deferred.promise

errors = {}
errors.loadModule = (error) ->
  return if /^Missing config file:/.test error.message
  throw error
