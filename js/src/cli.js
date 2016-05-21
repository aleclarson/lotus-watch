var ErrorMap, Path, Q, errors, inArray, log, sync, syncFs;

ErrorMap = require("ErrorMap");

inArray = require("in-array");

syncFs = require("io/sync");

Path = require("path");

sync = require("sync");

log = require("log");

Q = require("q");

module.exports = function() {
  var Module, initModule;
  Module = lotus.Module;
  log.moat(1);
  log.white("Crawling: ");
  log.yellow(lotus.path);
  log.moat(1);
  initModule = function(mod) {
    return mod.load(["config", "plugins"]).fail(function(error) {
      return errors.load.resolve(error, function() {
        return log.yellow(mod.name);
      });
    }).done();
  };
  Module.watch(lotus.path, {
    add: function(mod) {
      return initModule(mod).done();
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
          if (newLength > log.size[0] - log.indent) {
            log.moat(0);
          }
          log[color](newPart);
        }
        log.popIndent();
      } else {
        log.white("Found " + (log.color.green.dim(0)) + " modules!");
      }
      return Q.all(sync.map(mods, function(mod) {
        return initModule(mod);
      })).then(function() {
        log.moat(1);
        log.gray("Watching files...");
        return log.moat(1);
      });
    }
  });
  return Q.defer().promise;
};

errors = {
  load: ErrorMap({
    quiet: ["'package.json' could not be found!"]
  })
};

//# sourceMappingURL=../../map/src/cli.map