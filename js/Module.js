// Generated by CoffeeScript 1.12.4
var Chokidar, Event, Promise, SortedArray, assertType, emptyFunction, errors, inArray, isType, log, match, path, sync, syncFs, watchFiles;

emptyFunction = require("emptyFunction");

SortedArray = require("SortedArray");

assertType = require("assertType");

Chokidar = require("chokidar");

Promise = require("Promise");

inArray = require("in-array");

syncFs = require("io/sync");

isType = require("isType");

match = require("micromatch");

Event = require("Event");

path = require("path");

sync = require("sync");

log = require("log");

module.exports = function(type) {
  type.defineMethods({
    watch: function(options, listeners) {
      var files, notify, onFileFound, onceFilesReady, watcher;
      assertType(options, Object.or(Array, String));
      if (Array.isArray(options)) {
        options = {
          include: options.map((function(_this) {
            return function(pattern) {
              if (pattern[0] !== path.sep) {
                return path.join(_this.path, pattern);
              } else {
                return pattern;
              }
            };
          })(this))
        };
      } else if (isType(options, String)) {
        options = {
          include: options[0] !== path.sep ? path.join(this.path, options) : options
        };
      }
      files = SortedArray([], function(a, b) {
        a = a.path.toLowerCase();
        b = b.path.toLowerCase();
        if (a === b) {
          return 0;
        } else if (a > b) {
          return 1;
        } else {
          return -1;
        }
      });
      onFileFound = (function(_this) {
        return function(filePath) {
          var file;
          if (!syncFs.isFile(filePath)) {
            return;
          }
          if (file = _this.getFile(filePath)) {
            return files.insert(file);
          }
        };
      })(this);
      onceFilesReady = (function(_this) {
        return function() {
          var supportedEvents;
          notify("ready", files.array);
          watcher.removeListener("add", onFileFound);
          supportedEvents = {
            add: 1,
            change: 1,
            unlink: 1,
            addDir: 1,
            unlinkDir: 1
          };
          return watcher.on("all", function(event, filePath) {
            var file, newCode, oldCode;
            if (!supportedEvents[event]) {
              log.moat(1);
              log("Warning: " + _this.name + "\nUnsupported event: " + event + "\nFile path: " + filePath);
              log.moat(1);
              return;
            }
            if (event === "addDir") {
              return;
            }
            if (event === "unlinkDir") {
              return;
            }
            file = _this.files[filePath];
            if (event === "add") {
              if (file) {
                return;
              }
              file = _this.getFile(filePath);
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
            }
          });
        };
      })(this);
      watcher = Chokidar.watch(options.include, {
        ignored: options.exclude
      });
      watcher.on("add", onFileFound);
      watcher.once("ready", onceFilesReady);
      notify = lotus.Module._resolveListeners(listeners);
      return watchFiles(options, notify);
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
        dirPath = path.resolve(process.cwd(), dirPath);
      }
      if (!syncFs.isDir(dirPath)) {
        throw Error("Expected a directory: '" + dirPath + "'");
      }
      notify = this._resolveListeners(listeners);
      listener = this._didChange(notify);
      if (!this._watching[dirPath]) {
        this._initialWatch(dirPath, notify);
        return listener.start();
      }
      this._watching[dirPath].promise.then(function(mods) {
        return notify("ready", mods);
      });
      return listener.start();
    },
    stopWatching: function(filePath) {
      var watcher;
      if (!this._watching[filePath]) {
        return;
      }
      watcher = this._watching[filePath].watcher;
      watcher.close();
      delete this._watching[filePath];
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
        return loading.push(modPath);
      };
      onModulesReady = function() {
        var onModuleAdded, onModuleDeleted, onModuleEvent, supportedEvents;
        watcher.removeListener("addDir", onModuleFound);
        supportedEvents = {
          add: 1,
          change: 1,
          unlink: 1,
          addDir: 1,
          unlinkDir: 1
        };
        onModuleAdded = function(modName, modPath) {
          if (lotus.Module.has(modName)) {
            return;
          }
          return loadModule(modPath).then(function(mod) {
            if (mod) {
              mods.insert(mod);
              lotus.Module._didChange.emit("add", mod);
            }
          });
        };
        onModuleDeleted = function(modName, mod) {
          if (!lotus.Module.has(modName)) {
            return;
          }
          mod = lotus.Module.get(modName);
          lotus.Module._didChange.emit("unlink", mod);
          mods.remove(mod);
        };
        onModuleEvent = function(event, modPath) {
          var modName;
          if (!supportedEvents[event]) {
            log.moat(1);
            log("Warning: " + this.name + "\nUnsupported event: " + event + "\nFile path: " + modPath);
            log.moat(1);
            return;
          }
          if (event === "add") {
            return;
          }
          if (event === "change") {
            return;
          }
          if (event === "unlink") {
            return;
          }
          modName = path.relative(dirPath, modPath);
          if (event === "addDir") {
            onModuleAdded(modName, modPath);
          } else if (event === "unlinkDir") {
            onModuleDeleted(modName, modPath);
          }
        };
        return Promise.all(loading, function(modPath) {
          return loadModule(modPath).then(function(mod) {
            mod && mods.insert(mod);
          });
        }).then(function() {
          deferred.resolve(mods.array);
          notify("ready", mods.array);
          return watcher.on("all", onModuleEvent);
        });
      };
      loadModule = function(modPath) {
        if (modPath === dirPath) {
          return Promise.resolve();
        }
        return lotus.Module.load(modPath).then(function(mod) {
          if (!mod) {
            return;
          }
          if (lotus.isModuleIgnored(mod.name)) {
            return;
          }
          return mod;
        }).fail(errors.loadModule);
      };
      watcher.on("addDir", onModuleFound);
      watcher.once("ready", onModulesReady);
      return this._watching[dirPath] = {
        watcher: watcher,
        promise: deferred.promise
      };
    }
  });
};

watchFiles = function(arg, notify) {
  var exclude, include;
  include = arg.include, exclude = arg.exclude;
  if (Array.isArray(include)) {
    include = include.length > 1 ? "(" + (include.join("|")) + ")" : include[0];
  }
  if (Array.isArray(exclude)) {
    exclude = exclude.length > 1 ? "(" + (exclude.join("|")) + ")" : exclude[0];
  }
  return lotus.File.watch({
    include: include,
    exclude: exclude
  }, notify);
};

errors = {};

errors.loadModule = function(error) {
  var message;
  message = error.message;
  if (message.startsWith("Module path must be a directory:")) {
    return;
  }
  if (message.startsWith("Missing config file:")) {
    return;
  }
  throw error;
};
