
{ isMatch } = require "micromatch"

emptyFunction = require "emptyFunction"
assertType = require "assertType"
isType = require "isType"
Event = require "Event"

module.exports = (type) ->

  type.defineValues

    _deleted: no

  type.defineMethods

    _delete: ->

      return if @_deleted
      @_deleted = yes

      delete @module.files[@name]

  type.defineStatics

    _didChange: Event()

    # Watch files that match the given patterns.
    watch: (options, notify) ->

      if isType options, Function
        notify = options
        options = {}

      else if isType options, String
        options = { include: options }

      else
        options ?= {}

      assertType options, Object
      assertType notify, Function

      if options.include?
        isIncluded = (file) -> isMatch file.path, options.include
      else isIncluded = emptyFunction.thatReturnsTrue

      if options.exclude?
        isExcluded = (file) -> isMatch file.path, options.exclude
      else isExcluded = emptyFunction.thatReturnsFalse

      onFileChange = (event, file) ->
        return if not isIncluded file
        return if isExcluded file
        notify event, file, options

      return lotus.File._didChange(onFileChange).start()
