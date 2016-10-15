
emptyFunction = require "emptyFunction"
SortedArray = require "sorted-array"
assertType = require "assertType"
Chokidar = require "chokidar"
Promise = require "Promise"
inArray = require "in-array"
syncFs = require "io/sync"
isType = require "isType"
match = require "micromatch"
Event = require "Event"
path = require "path"
sync = require "sync"
log = require "log"

module.exports = (type) ->

  type.defineMethods

    # Search this module for files that match the given pattern.
    watch: (options, listeners) ->
      assertType options, Object.or Array, String

      if Array.isArray options
        options = include: options.map (pattern) =>
          if pattern[0] isnt path.sep
          then path.join @path, pattern
          else pattern

      else if isType options, String
        options = include:
          if options[0] isnt path.sep
          then path.join @path, options
          else options

      files = SortedArray [], (a, b) ->
        a = a.path.toLowerCase()
        b = b.path.toLowerCase()
        if a is b then 0
        else if a > b then 1
        else -1

      onFileFound = (filePath) =>
        return unless syncFs.isFile filePath
        file = @getFile filePath
        files.insert file

      onceFilesReady = =>

        notify "ready", files.array
        watcher.removeListener "add", onFileFound

        supportedEvents = {add:1, change:1, unlink:1, addDir:1, unlinkDir:1}

        watcher.on "all", (event, filePath) =>

          unless supportedEvents[event]
            log.moat 1
            log """
              Warning: #{@name}
              Unsupported event: #{event}
              File path: #{filePath}
            """
            log.moat 1
            return

          # Ignore directory events.
          return if event is "addDir"
          return if event is "unlinkDir"

          file = @files[filePath]

          if event is "add"
            return if file
            file = @getFile filePath
            files.insert file

          return unless file

          if event is "change"
            oldCode = file.read { sync: yes } if file._reading
            newCode = file.read { sync: yes, force: yes }
            return if oldCode is newCode

          lotus.File._didChange.emit event, file

          if event is "unlink"
            files.remove file
          return

      watcher = Chokidar.watch options.include,
        ignored: options.exclude

      watcher.on "add", onFileFound
      watcher.once "ready", onceFilesReady

      notify = lotus.Module._resolveListeners listeners
      return watchFiles options, notify

  type.defineStatics

    didChange: get: ->
      @_didChange.listenable

    # Watch modules that exist in the given directory!
    watch: (dirPath, listeners) ->

      assertType dirPath, String

      if dirPath[0] is "."
        dirPath = path.resolve process.cwd(), dirPath

      if not syncFs.isDir dirPath
        throw Error "Expected a directory: '#{dirPath}'"

      notify = @_resolveListeners listeners
      listener = @_didChange notify

      unless @_watching[dirPath]
        @_initialWatch dirPath, notify
        return listener.start()

      @_watching[dirPath].promise
        .then (mods) -> notify "ready", mods
      return listener.start()

    stopWatching: (filePath) ->
      return unless @_watching[filePath]
      { watcher } = @_watching[filePath]
      watcher.close()
      delete @_watching[filePath]
      return

    # The module directories being watched.
    _watching: Object.create null

    # Emits when a module is added or deleted.
    _didChange: Event()

    _resolveListeners: (listeners) ->

      if isType listeners, Function
        return listeners

      else if isType listeners, Object
        shift = Array::shift
        return ->
          event = shift.call arguments
          onEvent = listeners[event]
          onEvent.apply null, arguments if onEvent

      return emptyFunction

    _initialWatch: (dirPath, notify) ->

      deferred = Promise.defer()

      watcher = Chokidar.watch dirPath, {depth: 0}

      loading = []
      mods = SortedArray [], (a, b) ->
        a = a.name.toLowerCase()
        b = b.name.toLowerCase()
        if a > b then 1 else -1

      onModuleFound = (modPath) ->
        loading.push modPath

      onModulesReady = ->

        watcher.removeListener "addDir", onModuleFound

        supportedEvents = {add:1, change:1, unlink:1, addDir:1, unlinkDir:1}

        onModuleAdded = (modName, modPath) ->
          if lotus.Module.has modName
            return # TODO: Delete the pre-existing module.
          loadModule(modPath).then (mod) ->
            if mod
              mods.insert mod
              lotus.Module._didChange.emit "add", mod
            return

        onModuleDeleted = (modName, mod) ->
          return if not lotus.Module.has modName
          mod = lotus.Module.get modName
          lotus.Module._didChange.emit "unlink", mod
          mods.remove mod
          return

        onModuleEvent = (event, modPath) ->

          unless supportedEvents[event]
            log.moat 1
            log """
              Warning: #{@name}
              Unsupported event: #{event}
              File path: #{modPath}
            """
            log.moat 1
            return

          # Ignore file events.
          return if event is "add"
          return if event is "change"
          return if event is "unlink"

          modName = path.relative dirPath, modPath
          if event is "addDir"
            onModuleAdded modName, modPath
          else if event is "unlinkDir"
            onModuleDeleted modName, modPath
          return

        Promise.all loading, (modPath) ->
          loadModule(modPath).then (mod) ->
            mod and mods.insert mod
            return

        .then ->
          deferred.resolve mods.array
          notify "ready", mods.array
          watcher.on "all", onModuleEvent

      loadModule = (modPath) ->
        if modPath is dirPath
          return Promise()
        lotus.Module.load modPath
        .then (mod) ->
          return if not mod
          return if lotus.isModuleIgnored mod.name
          return mod
        .fail errors.loadModule

      watcher.on "addDir", onModuleFound
      watcher.once "ready", onModulesReady

      @_watching[dirPath] = {
        watcher
        promise: deferred.promise
      }

watchFiles = ({include, exclude}, notify) ->

  if Array.isArray include
    include =
      if include.length > 1
      then "(#{include.join "|"})"
      else include[0]

  if Array.isArray exclude
    exclude =
      if exclude.length > 1
      then "(#{exclude.join "|"})"
      else exclude[0]

  return lotus.File.watch {include, exclude}, notify

errors = {}
errors.loadModule = (error) ->
  {message} = error
  return if message.startsWith "Module path must be a directory:"
  return if message.startsWith "Missing config file:"
  throw error
