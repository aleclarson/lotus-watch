var Chokidar, ErrorMap, Event, Path, Q, SortedArray, assert, assertType, emptyFunction, errors, isType, match, sync, syncFs;

emptyFunction = require("emptyFunction");

SortedArray = require("sorted-array");

assertType = require("assertType");

ErrorMap = require("ErrorMap");

Chokidar = require("chokidar");

syncFs = require("io/sync");

isType = require("isType");

assert = require("assert");

match = require("micromatch");

Event = require("event");

Path = require("path");

sync = require("sync");

Q = require("q");

module.exports = function(type) {
  type.defineValues({
    _watching: function() {
      return Object.create(null);
    },
    _deleted: false
  });
  type.defineMethods({
    watch: function(pattern, listeners) {
      var File, Module, listener, notifyListeners, relPath;
      if (Array.isArray(pattern)) {
        return Q.all(sync.map(pattern, (function(_this) {
          return function(pattern) {
            return _this.watch(pattern, listeners);
          };
        })(this)));
      }
      Module = lotus.Module, File = lotus.File;
      assertType(pattern, String);
      if (pattern[0] === "/") {
        relPath = Path.relative(this.path, pattern);
        assert(relPath.slice(0, 2) !== "..", {
          pattern: pattern,
          mod: this,
          reason: "Absolute pattern does not belong to this module."
        });
      } else {
        pattern = Path.join(this.path, pattern);
      }
      notifyListeners = Module._resolveListeners(listeners);
      listener = File.watch(pattern, notifyListeners);
      if (!this._watching[pattern]) {
        this._initialWatch(pattern, notifyListeners);
        return listener;
      }
      this._watching[pattern].promise.then(function(files) {
        return notifyListeners("ready", files);
      }).done();
      return listener;
    },
    stopWatching: function(pattern) {
      var watcher;
      if (!this._watching[pattern]) {
        return;
      }
      watcher = this._watching[pattern].watcher;
      watcher.close();
      delete this._watching[pattern];
    },
    _initialWatch: function(pattern, notifyListeners) {
      var File, deferred, files, onFileFound, onceFilesReady, watcher;
      File = lotus.File;
      deferred = Q.defer();
      watcher = Chokidar.watch();
      files = SortedArray([], function(a, b) {
        a = a.path.toLowerCase();
        b = b.path.toLowerCase();
        if (a > b) {
          return 1;
        } else {
          return -1;
        }
      });
      onFileFound = (function(_this) {
        return function(path) {
          var file;
          if (!syncFs.isFile(path)) {
            return;
          }
          file = File(path, _this);
          return files.insert(file);
        };
      })(this);
      onceFilesReady = (function(_this) {
        return function() {
          var validEvents;
          watcher.removeListener("add", onFileFound);
          validEvents = {
            add: true,
            change: true,
            unlink: true
          };
          watcher.on("all", function(event, path) {
            var file, newCode, oldCode;
            if (!validEvents[event]) {
              log.moat(1);
              log.yellow("Warning: ");
              log.white(_this.name);
              log.moat(0);
              log.gray.dim("Invalid event name: ");
              log.gray("'" + event + "'");
              log.moat(1);
              return;
            }
            file = _this.files[path];
            if (event === "add") {
              if (file) {
                return;
              }
              file = File(path, _this);
              files.insert(file);
            }
            if (!file) {
              return;
            }
            if (event === "change") {
              if (file._reading) {
                oldCode = file.read({
                  sync: true
                });
              }
              newCode = file.read({
                sync: true,
                force: true
              });
              if (oldCode === newCode) {
                return;
              }
            }
            File._didChange.emit(event, file);
            if (event === "unlink") {
              files.remove(file);
              return file._delete();
            }
          });
          notifyListeners("ready", files.array);
          return deferred.fulfill(files.array);
        };
      })(this);
      watcher.on("add", onFileFound);
      watcher.once("ready", onceFilesReady);
      watcher.add(pattern);
      return this._watching[pattern] = {
        watcher: watcher,
        promise: deferred.promise
      };
    },
    _delete: function() {
      if (this._deleted) {
        return;
      }
      return this._deleted = true;
    }
  });
  return type.defineStatics({
    didChange: {
      get: function() {
        return this._didChange.listenable;
      }
    },
    watch: function(path, listeners) {
      var listener, notifyListeners;
      assertType(path, String);
      if (path[0] === ".") {
        path = Path.resolve(process.cwd(), path);
      }
      assert(syncFs.isDir(path), {
        path: path,
        reason: "Expected a directory!"
      });
      notifyListeners = this._resolveListeners(listeners);
      listener = this._didChange(notifyListeners);
      if (!this._watching[path]) {
        this._initialWatch(path, notifyListeners);
        return listener;
      }
      this._watching[path].promise.then(function(mods) {
        return notifyListeners("ready", mods);
      }).done();
      return listener;
    },
    stopWatching: function(path) {
      var watcher;
      if (!this._watching[path]) {
        return;
      }
      watcher = this._watching[path].watcher;
      watcher.close();
      delete this._watching[path];
    },
    _watching: Object.create(null),
    _didChange: Event(),
    _resolveListeners: function(listeners) {
      var shift;
      if (isType(listeners, Function)) {
        return listeners;
      } else if (isType(listeners, Object)) {
        shift = Array.prototype.shift;
        return function() {
          var event, onEvent;
          event = shift.call(arguments);
          onEvent = listeners[event];
          if (onEvent) {
            return onEvent.apply(null, arguments);
          }
        };
      }
      return emptyFunction;
    },
    _initialWatch: function(path, notifyListeners) {
      var Module, deferred, initModule, mods, onModuleFound, onModulesReady, watcher;
      Module = lotus.Module;
      deferred = Q.defer();
      watcher = Chokidar.watch(path, {
        depth: 0
      });
      mods = SortedArray([], function(a, b) {
        a = a.name.toLowerCase();
        b = b.name.toLowerCase();
        if (a > b) {
          return 1;
        } else {
          return -1;
        }
      });
      initModule = function(path) {
        var error, name;
        if (path === lotus.path) {
          return;
        }
        name = Path.relative(lotus.path, path);
        try {
          return Module(name);
        } catch (error1) {
          error = error1;
          errors.init.resolve(error, function() {
            return log.yellow(name);
          });
          return null;
        }
      };
      onModuleFound = function(path) {
        var mod;
        mod = initModule(path);
        if (!mod) {
          return;
        }
        return mods.insert(mod);
      };
      onModulesReady = function() {
        var validEvents;
        watcher.removeListener("addDir", onModuleFound);
        validEvents = {
          add: true,
          change: true,
          unlink: true
        };
        watcher.on("all", function(event, path) {
          var mod, name;
          if (!validEvents[event]) {
            log.moat(1);
            log.yellow("Warning: ");
            log.white("Module.watch()");
            log.moat(0);
            log.gray.dim("Invalid event name: ");
            log.gray("'" + event + "'");
            log.moat(1);
            return;
          }
          name = Path.relative(lotus.path, path);
          mod = Module.cache[name];
          if (event === "add") {
            if (mod) {
              return;
            }
            mod = initModule(path);
            if (mod) {
              mods.insert(mod);
            }
          }
          if (!mod) {
            return;
          }
          Module._didChange.emit(event, mod);
          if (event === "unlink") {
            return mods.remove(mod);
          }
        });
        notifyListeners("ready", mods.array);
        return deferred.fulfill(mods.array);
      };
      watcher.on("addDir", onModuleFound);
      watcher.once("ready", onModulesReady);
      return this._watching[path] = {
        watcher: watcher,
        promise: deferred.promise
      };
    }
  });
};

errors = {
  init: ErrorMap({
    quiet: ["Module path must be a directory!", "Module with that name already exists!", "Module ignored by global config file!"]
  })
};

//# sourceMappingURL=../../map/src/Module.map
