
# lotus-watch v2.0.1 ![stable](https://img.shields.io/badge/stability-stable-4EBA0F.svg?style=flat)

A global plugin for [aleclarson/lotus](https://github.com/aleclarson/lotus).

### Command-line API

```sh
# Run the local plugins of each module.
# Keep the process alive indefinitely.
lotus watch
```

### JS API

```js
const lotus = require('lotus');
const mod = lotus.modules.get(moduleName);

// Creates a `FileWatcher` with the given pattern(s) and options.
const watcher = mod.watch('**/*.js');

watcher.on('add', onFileAdded);
watcher.on('change', onFileChanged);
watcher.on('unlink', onFileDeleted);

watcher.once('ready', function(filePaths) {
  // Called when the watcher is fully initialized.
  // Passes a `Set` of strings representing the files found.
});

// Watch for added/deleted modules.
const moduleWatcher = lotus.watchModules(directory, options);

moduleWatcher.on('add', onModuleAdded);
moduleWatcher.on('unlink', onModuleDeleted);

moduleWatcher.once('ready', function(modules) {
  // Called when the watcher is fully initialized.
  // Passes an array of `lotus.Module` instances that were found.
});

// Does NOT create a `FileWatcher`!
// Instead, it only emits for files watched by a module.
const fileListener = lotus.watchFiles('**/*.js', function(event, filePath) {
  // Called for every added, changed, or deleted JS file.
});
```

