// Generated by CoffeeScript 1.12.4
exports.initCommands = function() {
  return {
    watch: function() {
      return require("./cli");
    }
  };
};

exports.initModuleType = function() {
  return require("./Module");
};

exports.initFileType = function() {
  return require("./File");
};