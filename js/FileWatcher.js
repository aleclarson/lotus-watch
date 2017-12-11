// Generated by CoffeeScript 1.11.1
var Event, SortedArray, Type, chokidar, type;

SortedArray = require("SortedArray");

chokidar = require("chokidar");

Event = require("eve");

Type = require("Type");

type = Type("FileWatcher");

type.defineArgs(function() {
  return {
    required: [true, false],
    types: [
      String.or(Array), {
        ignore: String.or(Array).Maybe,
        cwd: String.Maybe
      }
    ]
  };
});

type.defineMethods({
  close: function() {
    this._watcher.close();
  },
  on: function(event, callback) {
    return this._events.on(event, callback);
  },
  once: function(event, callback) {
    return this._events.once(event, callback);
  }
});

type.defineValues(function(patterns, options) {
  return {
    _isLoading: true,
    _files: new SortedArray(this._fileSorter),
    _filePaths: new Set,
    _watcher: this._watch(patterns, options),
    _events: Event.Map()
  };
});

type.defineBoundMethods({
  _onChange: function(event, filePath) {
    var file, mod;
    if (this._isLoading) {
      if (event === "add") {
        this._filePaths.add(filePath);
      } else if (event === "unlink") {
        this._filePaths["delete"](filePath);
      }
      return;
    }
    mod = lotus.modules.resolve(filePath);
    if (/^(addDir|unlinkDir)$/.test(event)) {
      this._events.emit(event, {
        path: filePath,
        module: mod
      });
      return;
    }
    file = mod.files[filePath];
    if (event === "add") {
      if (file) {
        return;
      }
      file = mod.getFile(filePath);
      this._files.insert(file);
      this._filePaths.add(filePath);
    }
    if (!file) {
      return;
    }
    if (event === "change") {
      file.invalidate();
    }
    this._events.emit(event, file);
    lotus.didFileChange.emit(event, file);
    if (event === "unlink") {
      this._files.remove(file);
      this._filePaths["delete"](filePath);
      delete mod.files[filePath];
    }
  }
});

type.definePrototype({
  _fileSorter: function(a, b) {
    a = a.path.toLowerCase();
    b = b.path.toLowerCase();
    if (a === b) {
      return 0;
    }
    if (a > b) {
      return 1;
    }
    return -1;
  }
});

type.defineMethods({
  _watch: function(patterns, options) {
    var watcher;
    if (options.ignore) {
      options.ignored = options.ignore;
      delete options.ignore;
    }
    watcher = chokidar.watch(patterns, options);
    watcher.on("all", this._onChange);
    watcher.once("ready", (function(_this) {
      return function() {
        _this._isLoading = false;
        _this._events.emit("ready", _this._filePaths);
        return _this._filePaths.forEach(function(filePath) {
          var file, mod;
          if (mod = lotus.modules.resolve(filePath)) {
            file = mod.getFile(filePath);
            if (file) {
              _this._files.insert(file);
            }
          }
        });
      };
    })(this));
    return watcher;
  }
});

module.exports = type.build();
