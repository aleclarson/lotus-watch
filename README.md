
# lotus-watch v1.2.0 ![stable](https://img.shields.io/badge/stability-stable-4EBA0F.svg?style=flat)

A global plugin for [aleclarson/lotus](https://github.com/aleclarson/lotus).

**TODO:** Update docs for v1.1.0

### `lotus watch`

Run the local plugins for each module.

Keep the process alive for file watchers.

### Module::watch(patterns, listeners)

Crawl the module for its files.

  • Watch a specific file pattern by passing
    a String as the first argument.

  • Must provide a Function that will be called
    for every file event.

### Module.watch(path, listeners)

Crawl the directory for its modules.

  • Calls the 2nd argument whenever a module is added or deleted.

  • Returns a Promise that resolves the initial modules.

### File.watch(patterns, listeners)

Watch files that were cached by 'module.watch()'.

  • This does NOT crawl anything.
    Use 'module.watch()' first!

  • Watch specific patterns by passing a String or
    an { include: String, exclude: String } shape
    as the first argument.

  • Must provide a Function that will be called
    for every file event.

  • Returns a Listener that can be used
    to stop receiving file events.
