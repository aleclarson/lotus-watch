
LazyVar = require "LazyVar"
Type = require "Type"

mixin = Type.Mixin()

mixin.defineMethods

  # Search this module for files that match the given pattern.
  watch: do ->

    FileWatcher = LazyVar ->
      require "./FileWatcher"

    return (pattern, options) ->
      FileWatcher.call pattern, options

module.exports = mixin.apply
