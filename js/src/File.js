var Event, assertType, emptyFunction, isMatch, isType;

isMatch = require("micromatch").isMatch;

emptyFunction = require("emptyFunction");

assertType = require("assertType");

isType = require("isType");

Event = require("Event");

module.exports = function(type) {
  type.defineValues({
    _deleted: false
  });
  type.defineMethods({
    _delete: function() {
      if (this._deleted) {
        return;
      }
      this._deleted = true;
      return delete this.module.files[this.name];
    }
  });
  return type.defineStatics({
    _didChange: Event(),
    watch: function(options, notify) {
      var isExcluded, isIncluded, onFileChange;
      if (isType(options, Function)) {
        notify = options;
        options = {};
      } else if (isType(options, String)) {
        options = {
          include: options
        };
      } else {
        if (options == null) {
          options = {};
        }
      }
      assertType(options, Object);
      assertType(notify, Function);
      if (options.include != null) {
        isIncluded = function(file) {
          return isMatch(file.path, options.include);
        };
      } else {
        isIncluded = emptyFunction.thatReturnsTrue;
      }
      if (options.exclude != null) {
        isExcluded = function(file) {
          return isMatch(file.path, options.exclude);
        };
      } else {
        isExcluded = emptyFunction.thatReturnsFalse;
      }
      onFileChange = function(event, file) {
        if (!isIncluded(file)) {
          return;
        }
        if (isExcluded(file)) {
          return;
        }
        return notify(event, file, options);
      };
      return lotus.File._didChange(onFileChange).start();
    }
  });
};

//# sourceMappingURL=../../map/src/File.map
