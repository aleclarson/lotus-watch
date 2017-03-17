
{isMatch} = require "micromatch"

emptyFunction = require "emptyFunction"
assertType = require "assertType"
LazyVar = require "LazyVar"
isType = require "isType"
Event = require "eve"
path = require "path"
fs = require "fsx"

# Emits when any watched file is changed.
lotus.didFileChange = Event()

# Watch files that match the given pattern(s).
lotus.watchFiles = (pattern, options, callback) ->

  if arguments.length is 1
    callback = pattern
    pattern = null
    options = {}

  else if arguments.length is 2
    callback = options
    if isType pattern, Object
      options = pattern
      pattern = null
    else options = {}

  assertType pattern, String.or(Array).Maybe, "pattern"
  assertType options, Object.Maybe, "options"
  assertType callback, Function, "callback"

  isIncluded =
    if pattern?
    then createMatcher pattern
    else emptyFunction.thatReturnsTrue

  isIgnored =
    if options.ignored?
    then createMatcher options.ignored
    else emptyFunction.thatReturnsFalse

  lotus.didFileChange (event, file) ->
    if isIncluded file.path
      return if isIgnored file.path
      callback event, file
    return

lotus.watchModules = do ->

  ModuleWatcher = LazyVar ->
    require "./ModuleWatcher"

  return (root, options) ->
    assertType root, String
    assertType options, Object.Maybe

    if root[0] is "."
      root = path.resolve process.cwd(), root

    unless fs.isDir root
      throw Error "Expected a directory: '#{root}'"

    return ModuleWatcher.call root, options

#
# Internal helpers
#

createMatcher = (pattern) ->

  if Array.isArray pattern
    pattern = "(" + pattern.join("|") + ")"

  return (file) ->
    isMatch file.path, pattern
