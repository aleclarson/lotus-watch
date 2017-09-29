
SortedArray = require "SortedArray"
chokidar = require "chokidar"
Event = require "eve"
Type = require "Type"

type = Type "FileWatcher"

type.defineArgs ->

  required: [yes, no]

  types: [
    String.or Array
    ignore: String.or(Array).Maybe
    cwd: String.Maybe
  ]

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

type.defineValues (patterns, options) ->

  _isLoading: yes

  _files: SortedArray [], @_fileSorter

  _filePaths: new Set

  _watcher: @_watch patterns, options

  _events: Event.Map()

type.defineBoundMethods

  _onChange: (event, filePath) ->

    if @_isLoading
      if event is "add"
        @_filePaths.add filePath
      else if event is "unlink"
        @_filePaths.delete filePath
      return

    # Ignore directory events.
    return if /(addDir|unlinkDir)/.test event

    mod = lotus.modules.resolve filePath
    file = mod.files[filePath]

    if event is "add"
      return if file
      file = mod.getFile filePath
      @_files.insert file
      @_filePaths.add filePath

    return unless file

    if event is "change"
      file.invalidate()

    @_events.emit event, file
    lotus.didFileChange.emit event, file

    if event is "unlink"
      @_files.remove file
      @_filePaths.delete filePath
    return

type.definePrototype

  _fileSorter: (a, b) ->
    a = a.path.toLowerCase()
    b = b.path.toLowerCase()
    return 0 if a is b
    return 1 if a > b
    return -1

type.defineMethods

  _watch: (patterns, options) ->

    if options.ignore
      options.ignored = options.ignore
      delete options.ignore

    watcher = chokidar.watch patterns, options
    watcher.on "all", @_onChange

    watcher.once "ready", =>
      @_isLoading = no
      @_events.emit "ready", @_filePaths
      @_filePaths.forEach (filePath) =>
        if mod = lotus.modules.resolve filePath
          file = mod.getFile filePath
          @_files.insert file if file
        return

    return watcher

module.exports = type.build()
