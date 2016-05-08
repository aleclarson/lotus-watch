
match = require "micromatch"
Event = require "event"

module.exports = (type) ->

  type.defineValues

    _deleted: no

  type.defineMethods

    _delete: ->

      return if @_deleted
      @_deleted = yes

      { File } = lotus

      delete @module.files[@name]

  type.defineStatics

    _didChange: Event()

    # Watch files that match the given patterns.
    watch: (options, notifyListeners) ->

      { File } = lotus

      if isType options, String
        options = { include: options }
      else
        if isType options, Function
          onChange = options
          options = {}
        else options ?= {}
        options.include ?= "**/*"

      return File._didChange (event, file) ->

        return if match(file.path, options.include).length is 0

        return if options.exclude? and match(file.path, options.exclude).length > 0

        notifyListeners event, file, options
