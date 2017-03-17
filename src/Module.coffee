
LazyVar = require "LazyVar"
Type = require "Type"

mixin = Type.Mixin()

mixin.defineMethods

  # Search this module for files that match the given pattern.
  watch: do ->

    FileWatcher = LazyVar ->
      require "./FileWatcher"

    return (patterns, options = {}) ->
      options.cwd = @path
      FileWatcher.call patterns, options

module.exports = mixin.apply
