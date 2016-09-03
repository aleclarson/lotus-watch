
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
Path = require "path"
sync = require "sync"
log = require "log"

module.exports = (type) ->

  type.defineValues

    # The keys are patterns passed to 'module.watch'.
    # The values are shaped like { watcher, promise }.
    _watching: -> Object.create null

    # This module has been deleted!
    _deleted: no

  type.defineMethods

    # Search this module for files that match the given pattern.
    watch: (pattern, listeners) ->

      if Array.isArray pattern
        return Promise.map pattern, (pattern) =>
          @watch pattern, listeners

      assertType pattern, String

      if pattern[0] is "/"
        relPath = Path.relative @path, pattern
        if relPath[0..1] is ".."
          throw Error "Absolute pattern does not belong to this module!"

      else
        pattern = Path.join @path, pattern

      notify = lotus.Module._resolveListeners listeners
      listener = lotus.File.watch pattern, notify

      unless @_watching[pattern]
        @_initialWatch pattern, notify
        return listener

      @_watching[pattern].promise

      .then (files) ->
        notify "ready", files

      return listener

    stopWatching: (pattern) ->
      return unless @_watching[pattern]
      { watcher } = @_watching[pattern]
      watcher.close()
      delete @_watching[pattern]
      return

    _initialWatch: (pattern, notify) ->

      deferred = Promise.defer()

      watcher = Chokidar.watch()

      files = SortedArray [], (a, b) ->
        a = a.path.toLowerCase()
        b = b.path.toLowerCase()
        if a is b then 0
        else if a > b then 1
        else -1

      onFileFound = (path) =>
        return unless syncFs.isFile path
        file = @getFile path
        files.insert file

      onceFilesReady = =>

        watcher.removeListener "add", onFileFound

        validEvents = { add: yes, change: yes, unlink: yes }

        watcher.on "all", (event, path) =>

          unless validEvents[event]
            log.moat 1
            log.yellow "Warning: "
            log.white @name
            log.moat 0
            log.gray.dim "Invalid event name: "
            log.gray "'#{event}'"
            log.moat 1
            return

          file = @files[path]

          if event is "add"
            return if file
            file = @getFile path
            files.insert file

          return unless file

          if event is "change"
            oldCode = file.read { sync: yes } if file._reading
            newCode = file.read { sync: yes, force: yes }
            return if oldCode is newCode

          lotus.File._didChange.emit event, file

          if event is "unlink"
            files.remove file
            file._delete() # TODO: Detect when a directory of files is deleted.

        notify "ready", files.array

        deferred.resolve files.array

      watcher.on "add", onFileFound
      watcher.once "ready", onceFilesReady

      watcher.add pattern
      @_watching[pattern] = {
        watcher
        promise: deferred.promise
      }

    # TODO: Use a 'retainCount' to prevent deleting early.
    _delete: ->
      return if @_deleted
      @_deleted = yes
      # TODO: delete lotus.Module.delete @name

  type.defineStatics

    didChange: get: ->
      @_didChange.listenable

    # Watch modules that exist in the given directory!
    watch: (dirPath, listeners) ->

      assertType dirPath, String

      if dirPath[0] is "."
        dirPath = Path.resolve process.cwd(), dirPath

      if not syncFs.isDir dirPath
        throw Error "Expected a directory: '#{dirPath}'"

      notify = @_resolveListeners listeners
      listener = @_didChange notify

      unless @_watching[dirPath]
        @_initialWatch dirPath, notify
        return listener

      @_watching[dirPath].promise
      .then (mods) -> notify "ready", mods
      return listener

    stopWatching: (path) ->
      return unless @_watching[path]
      { watcher } = @_watching[path]
      watcher.close()
      delete @_watching[path]
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

      watcher = Chokidar.watch dirPath, { depth: 0 }

      loading = []
      mods = SortedArray [], (a, b) ->
        a = a.name.toLowerCase()
        b = b.name.toLowerCase()
        if a > b then 1 else -1

      onModuleFound = (modPath) ->
        mod = loadModule modPath
        .then (mod) -> mod and mods.insert mod
        loading.push mod

      onModulesReady = ->

        watcher.removeListener "addDir", onModuleFound

        # TODO: Support 'addDir' and 'unlinkDir'!
        validEvents = { add: yes, change: yes, unlink: yes }

        onModuleEvent = (event, modPath) ->

          unless validEvents[event]
            log.moat 1
            log.yellow "Warning: "
            log.white "Module.watch()"
            log.moat 0
            log.gray.dim "Unhandled event name: "
            log.gray "'#{event}'"
            log.moat 1
            return

          modName = Path.relative dirPath, modPath
          if lotus.Module.has modName
            mod = lotus.Module.get modName

          if event is "add"
            return if mod
            return loadModule modPath
            .then (mod) ->
              return if not mod
              mods.insert mod
              lotus.Module._didChange.emit event, mod

          return if not mod
          lotus.Module._didChange.emit event, mod
          mods.remove mod if event is "unlink"

        Promise.all(loading).then ->
          deferred.resolve mods.array
          notify "ready", mods.array
          watcher.on "all", onModuleEvent

      loadModule = Promise.wrap (modPath) ->
        return if modPath is dirPath
        lotus.Module.load modPath
        .then (mod) -> mod if mod and not lotus.isModuleIgnored mod.name
        .fail errors.loadModule

      watcher.on "addDir", onModuleFound
      watcher.once "ready", onModulesReady

      @_watching[dirPath] = {
        watcher
        promise: deferred.promise
      }

errors = {}
errors.loadModule = (error) ->
  return if /^Missing config file:/.test error.message
  throw error
