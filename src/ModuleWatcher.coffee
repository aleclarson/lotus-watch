
SortedArray = require "SortedArray"
chokidar = require "chokidar"
Event = require "eve"
Type = require "Type"
path = require "path"

type = Type "ModuleWatcher"

type.defineArgs ->

  required: [yes, no]

  types: [
    String.or Array
    ignored: String.or Array
  ]

type.defineGetters

  isLoading: -> @_isLoading

type.defineMethods

  close: ->
    @_watcher.close()
    return

  on: (event, callback) ->
    @_events.on event, callback

  once: (event, callback) ->
    @_events.once event, callback

#
# Internal
#

type.defineValues (root, options) ->

  _isLoading: yes

  _root: root

  _modules: SortedArray [], @_moduleSorter

  _modulePaths: new Set

  _watcher: @_watch root, options

  _events: Event.Map()

type.defineBoundMethods

  _onChange: (event, modPath) ->

    return if modPath is @_root

    if @_isLoading
      if event is "addDir"
        @_modulePaths.add modPath
      else if event is "unlinkDir"
        @_modulePaths.delete modPath
      return

    if event is "addDir"
      @_addModule modPath
    else if event is "unlinkDir"
      @_removeModule modPath
    return

type.definePrototype

  _moduleSorter: (a, b) ->
    a = a.name.toLowerCase()
    b = b.name.toLowerCase()
    if a > b then 1 else -1

type.defineMethods

  _watch: (root, options = {}) ->

    # Avoid crawling sub-directories.
    options.depth = 0

    watcher = chokidar.watch root, options
    watcher.on "all", @_onChange

    watcher.once "ready", =>
      @_isLoading = no
      @_modulePaths.forEach (modPath) =>
         @_modules.insert mod if mod = @_loadModule modPath
      @_events.emit "ready", @_modules.array

    return watcher

  _addModule: (modPath) ->
    modName = path.basename modPath
    return if lotus.modules.has modName
    return unless mod = @_loadModule modPath
    @_modulePaths.add modPath
    @_events.emit "add", mod

  _removeModule: (modPath) ->
    modName = path.basename modPath
    return unless lotus.modules.has modName
    mod = lotus.modules.delete modName
    @_events.emit "unlink", mod

  _loadModule: (modPath) ->

    try mod = lotus.modules.load modPath
    catch error
      errors.loadModule error
      return null

    if mod and not lotus.isModuleIgnored mod.name
    then mod
    else null

module.exports = type.build()

errors = {}
errors.loadModule = (error) ->
  {message} = error
  return if message.startsWith "Module path must be a directory:"
  return if message.startsWith "Missing config file:"
  throw error
