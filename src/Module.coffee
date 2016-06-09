
emptyFunction = require "emptyFunction"
SortedArray = require "sorted-array"
assertType = require "assertType"
ErrorMap = require "ErrorMap"
Chokidar = require "chokidar"
Promise = require "Promise"
syncFs = require "io/sync"
isType = require "isType"
assert = require "assert"
match = require "micromatch"
Event = require "event"
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

      { Module, File } = lotus

      assertType pattern, String

      if pattern[0] is "/"
        relPath = Path.relative @path, pattern
        assert relPath[0..1] isnt "..", { pattern, mod: this, reason: "Absolute pattern does not belong to this module." }

      else
        pattern = Path.join @path, pattern

      notifyListeners = Module._resolveListeners listeners
      listener = File.watch pattern, notifyListeners

      unless @_watching[pattern]
        @_initialWatch pattern, notifyListeners
        return listener

      @_watching[pattern].promise

      .then (files) ->
        notifyListeners "ready", files

      .done()

      return listener

    stopWatching: (pattern) ->
      return unless @_watching[pattern]
      { watcher } = @_watching[pattern]
      watcher.close()
      delete @_watching[pattern]
      return

    _initialWatch: (pattern, notifyListeners) ->

      { File } = lotus

      deferred = Promise.defer()

      watcher = Chokidar.watch()

      files = SortedArray [], (a, b) ->
        a = a.path.toLowerCase()
        b = b.path.toLowerCase()
        if a > b then 1 else -1

      onFileFound = (path) =>
        return unless syncFs.isFile path
        file = File path, this
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
            file = File path, this
            files.insert file

          return unless file

          if event is "change"
            oldCode = file.read { sync: yes } if file._reading
            newCode = file.read { sync: yes, force: yes }
            return if oldCode is newCode

          File._didChange.emit event, file

          if event is "unlink"
            files.remove file
            file._delete() # TODO: Detect when a directory of files is deleted.

        notifyListeners "ready", files.array

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
      # TODO: delete lotus.Module.cache[@name]

  type.defineStatics

    didChange: get: ->
      @_didChange.listenable

    # Watch modules that exist in the given directory!
    watch: (path, listeners) ->

      assertType path, String

      if path[0] is "."
        path = Path.resolve process.cwd(), path

      assert syncFs.isDir(path), { path, reason: "Expected a directory!" }

      notifyListeners = @_resolveListeners listeners
      listener = @_didChange notifyListeners

      unless @_watching[path]
        @_initialWatch path, notifyListeners
        return listener

      @_watching[path].promise

      .then (mods) ->
        notifyListeners "ready", mods

      .done()

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

    _initialWatch: (path, notifyListeners) ->

      { Module } = lotus

      deferred = Promise.defer()

      watcher = Chokidar.watch path, { depth: 0 }

      mods = SortedArray [], (a, b) ->
        a = a.name.toLowerCase()
        b = b.name.toLowerCase()
        if a > b then 1 else -1

      initModule = (path) ->
        return if path is lotus.path
        name = Path.relative lotus.path, path
        try Module name
        catch error
          errors.init.resolve error, ->
            log.yellow name
          return null

      onModuleFound = (path) ->
        mod = initModule path
        return unless mod
        mods.insert mod

      onModulesReady = ->

        watcher.removeListener "addDir", onModuleFound

        # TODO: Support 'addDir' and 'unlinkDir'!
        validEvents = { add: yes, change: yes, unlink: yes }

        watcher.on "all", (event, path) ->

          unless validEvents[event]
            log.moat 1
            log.yellow "Warning: "
            log.white "Module.watch()"
            log.moat 0
            log.gray.dim "Invalid event name: "
            log.gray "'#{event}'"
            log.moat 1
            return

          name = Path.relative lotus.path, path
          mod = Module.cache[name]

          if event is "add"
            return if mod
            mod = initModule path
            mods.insert mod if mod

          return unless mod
          Module._didChange.emit event, mod

          if event is "unlink"
            mods.remove mod

        notifyListeners "ready", mods.array

        deferred.resolve mods.array

      watcher.on "addDir", onModuleFound
      watcher.once "ready", onModulesReady

      @_watching[path] = {
        watcher
        promise: deferred.promise
      }

errors =

  init: ErrorMap
    quiet: [
      "Module path must be a directory!"
      "Module with that name already exists!"
      "Module ignored by global config file!"
    ]

  # load: ErrorMap
  #   quiet: [
  #     "Expected an existing directory!"
  #     "Failed to find configuration file!"
  #   ]
