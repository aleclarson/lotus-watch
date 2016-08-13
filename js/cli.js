var ErrorMap, Path, Promise, errors, inArray, log, sync, syncFs;

ErrorMap = require("ErrorMap");

Promise = require("Promise");

inArray = require("in-array");

syncFs = require("io/sync");

Path = require("path");

sync = require("sync");

log = require("log");

module.exports = function() {
  var Module;
  Module = lotus.Module;
  log.moat(1);
  log.white("Crawling: ");
  log.yellow(lotus.path);
  log.moat(1);
  Module.watch(lotus.path, {
    add: function(mod) {
      return mod.load(["config", "plugins"]).fail(errors.loadModule);
    },
    unlink: function(mod) {},
    ready: function(mods) {
      var color, i, index, len, module, newLength, newPart;
      log.moat(1);
      if (mods.length > 0) {
        log.white("Found " + (log.color.green(mods.length)) + " modules: ");
        log.moat(1);
        log.plusIndent(2);
        for (index = i = 0, len = mods.length; i < len; index = ++i) {
          module = mods[index];
          color = index % 2 ? "cyan" : "green";
          newPart = module.name + " ";
          newLength = log.line.length + newPart.length;
          if (log.size && newLength > log.size[0] - log.indent) {
            log.moat(0);
          }
          log[color](newPart);
        }
        log.popIndent();
      } else {
        log.white("Found " + (log.color.green.dim(0)) + " modules!");
      }
      return Promise.map(mods, function(mod) {
        return mod.load(["config", "plugins"]).fail(errors.loadModule);
      }).then(function() {
        log.moat(1);
        log.gray("Watching files...");
        return log.moat(1);
      });
    }
  });
  return Promise.defer().promise;
};

errors = {};

errors.loadModule = function(error) {
  if (/^Missing config file:/.test(error.message)) {
    return;
  }
  throw error;
};

//# sourceMappingURL=map/cli.map
