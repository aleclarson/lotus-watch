var Chokidar, Event, Path, Promise, SortedArray, assert, assertType, emptyFunction, errors, inArray, isType, log, match, sync, syncFs;

emptyFunction = require("emptyFunction");

SortedArray = require("sorted-array");

assertType = require("assertType");

Chokidar = require("chokidar");

Promise = require("Promise");

inArray = require("in-array");

syncFs = require("io/sync");

isType = require("isType");

assert = require("assert");

match = require("micromatch");

Event = require("Event");

Path = require("path");

sync = require("sync");

log = require("log");

module.exports = function(type) {
  type.defineValues({
    _watching: function() {
      return Object.create(null);
    },
    _deleted: false
  });
  type.defineMethods({
    watch: function(pattern, listeners) {
      var listener, notify, relPath;
      if (Array.isArray(pattern)) {
        return Promise.map(pattern, (function(_this) {
          return function(pattern) {
            return _this.watch(pattern, listeners);
          };
        })(this));
      }
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
      notify = lotus.Module._resolveListeners(listeners);
      listener = lotus.File.watch(pattern, notify);
      if (!this._watching[pattern]) {
        this._initialWatch(pattern, notify);
        return listener;
      }
      this._watching[pattern].promise.then(function(files) {
        return notify("ready", files);
      });
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
    _initialWatch: function(pattern, notify) {
      var deferred, files, onFileFound, onceFilesReady, watcher;
      deferred = Promise.defer();
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
          file = lotus.File(path, _this);
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
              file = lotus.File(path, _this);
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
            lotus.File._didChange.emit(event, file);
            if (event === "unlink") {
              files.remove(file);
              return file._delete();
            }
          });
          notify("ready", files.array);
          return deferred.resolve(files.array);
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
    watch: function(dirPath, listeners) {
      var listener, notify;
      assertType(dirPath, String);
      if (dirPath[0] === ".") {
        dirPath = Path.resolve(process.cwd(), dirPath);
      }
      if (!syncFs.isDir(dirPath)) {
        throw Error("Expected a directory: '" + dirPath + "'");
      }
      notify = this._resolveListeners(listeners);
      listener = this._didChange(notify);
      if (!this._watching[dirPath]) {
        this._initialWatch(dirPath, notify);
        return listener;
      }
      this._watching[dirPath].promise.then(function(mods) {
        return notify("ready", mods);
      });
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
    _initialWatch: function(dirPath, notify) {
      var deferred, loadModule, loading, mods, onModuleFound, onModulesReady, watcher;
      deferred = Promise.defer();
      watcher = Chokidar.watch(dirPath, {
        depth: 0
      });
      loading = [];
      mods = SortedArray([], function(a, b) {
        a = a.name.toLowerCase();
        b = b.name.toLowerCase();
        if (a > b) {
          return 1;
        } else {
          return -1;
        }
      });
      onModuleFound = function(modPath) {
        var mod;
        mod = loadModule(modPath).then(function(mod) {
          return mod && mods.insert(mod);
        });
        return loading.push(mod);
      };
      onModulesReady = function() {
        var onModuleEvent, validEvents;
        watcher.removeListener("addDir", onModuleFound);
        validEvents = {
          add: true,
          change: true,
          unlink: true
        };
        onModuleEvent = function(event, modPath) {
          var mod, modName;
          if (!validEvents[event]) {
            log.moat(1);
            log.yellow("Warning: ");
            log.white("Module.watch()");
            log.moat(0);
            log.gray.dim("Unhandled event name: ");
            log.gray("'" + event + "'");
            log.moat(1);
            return;
          }
          modName = Path.relative(dirPath, modPath);
          mod = lotus.Module.cache[modName];
          if (event === "add") {
            if (mod) {
              return;
            }
            return loadModule(modPath).then(function(mod) {
              if (!mod) {
                return;
              }
              mods.insert(mod);
              return lotus.Module._didChange.emit(event, mod);
            });
          }
          if (!mod) {
            return;
          }
          lotus.Module._didChange.emit(event, mod);
          if (event === "unlink") {
            return mods.remove(mod);
          }
        };
        return Promise.all(loading).then(function() {
          deferred.resolve(mods.array);
          notify("ready", mods.array);
          return watcher.on("all", onModuleEvent);
        });
      };
      loadModule = Promise.wrap(function(modPath) {
        if (modPath === dirPath) {
          return;
        }
        return lotus.Module.load(modPath).then(function(mod) {
          if (mod && !lotus.isModuleIgnored(mod.name)) {
            return mod;
          }
        }).fail(errors.loadModule);
      });
      watcher.on("addDir", onModuleFound);
      watcher.once("ready", onModulesReady);
      return this._watching[dirPath] = {
        watcher: watcher,
        promise: deferred.promise
      };
    }
  });
};

errors = {};

errors.loadModule = function(error) {
  if (/^Missing config file:/.test(error.message)) {
    return;
  }
  throw error;
};

//# sourceMappingURL=map/Module.map
