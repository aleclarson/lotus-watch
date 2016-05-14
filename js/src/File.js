var Event, isType, match;

isType = require("isType");

match = require("micromatch");

Event = require("event");

module.exports = function(type) {
  type.defineValues({
    _deleted: false
  });
  type.defineMethods({
    _delete: function() {
      var File;
      if (this._deleted) {
        return;
      }
      this._deleted = true;
      File = lotus.File;
      return delete this.module.files[this.name];
    }
  });
  return type.defineStatics({
    _didChange: Event(),
    watch: function(options, notifyListeners) {
      var File, onChange;
      File = lotus.File;
      if (isType(options, String)) {
        options = {
          include: options
        };
      } else {
        if (isType(options, Function)) {
          onChange = options;
          options = {};
        } else {
          if (options == null) {
            options = {};
          }
        }
        if (options.include == null) {
          options.include = "**/*";
        }
      }
      return File._didChange(function(event, file) {
        if (match(file.path, options.include).length === 0) {
          return;
        }
        if ((options.exclude != null) && match(file.path, options.exclude).length > 0) {
          return;
        }
        return notifyListeners(event, file, options);
      });
    }
  });
};

//# sourceMappingURL=../../map/src/File.map
