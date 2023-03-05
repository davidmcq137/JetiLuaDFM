goog.provide("goog.log");
goog.provide("goog.log.Level");
goog.provide("goog.log.LogBuffer");
goog.provide("goog.log.LogRecord");
goog.provide("goog.log.Logger");
goog.require("goog.asserts");
goog.require("goog.debug");
goog.log.Loggable;
goog.log.ENABLED = goog.define("goog.log.ENABLED", goog.debug.LOGGING_ENABLED);
goog.log.ROOT_LOGGER_NAME = "";
var goog$log$log$classdecl$var0 = function(name, value) {
  this.name = name;
  this.value = value;
};
goog$log$log$classdecl$var0.prototype.toString = function() {
  return this.name;
};
goog.log.Level = goog$log$log$classdecl$var0;
goog.log.Level.OFF = new goog.log.Level("OFF", Infinity);
goog.log.Level.SHOUT = new goog.log.Level("SHOUT", 1200);
goog.log.Level.SEVERE = new goog.log.Level("SEVERE", 1000);
goog.log.Level.WARNING = new goog.log.Level("WARNING", 900);
goog.log.Level.INFO = new goog.log.Level("INFO", 800);
goog.log.Level.CONFIG = new goog.log.Level("CONFIG", 700);
goog.log.Level.FINE = new goog.log.Level("FINE", 500);
goog.log.Level.FINER = new goog.log.Level("FINER", 400);
goog.log.Level.FINEST = new goog.log.Level("FINEST", 300);
goog.log.Level.ALL = new goog.log.Level("ALL", 0);
goog.log.Level.PREDEFINED_LEVELS = [goog.log.Level.OFF, goog.log.Level.SHOUT, goog.log.Level.SEVERE, goog.log.Level.WARNING, goog.log.Level.INFO, goog.log.Level.CONFIG, goog.log.Level.FINE, goog.log.Level.FINER, goog.log.Level.FINEST, goog.log.Level.ALL];
goog.log.Level.predefinedLevelsCache_ = null;
goog.log.Level.createPredefinedLevelsCache_ = function() {
  goog.log.Level.predefinedLevelsCache_ = {};
  for (var i = 0, level = undefined; level = goog.log.Level.PREDEFINED_LEVELS[i]; i++) {
    goog.log.Level.predefinedLevelsCache_[level.value] = level;
    goog.log.Level.predefinedLevelsCache_[level.name] = level;
  }
};
goog.log.Level.getPredefinedLevel = function(name) {
  if (!goog.log.Level.predefinedLevelsCache_) {
    goog.log.Level.createPredefinedLevelsCache_();
  }
  return goog.log.Level.predefinedLevelsCache_[name] || null;
};
goog.log.Level.getPredefinedLevelByValue = function(value) {
  if (!goog.log.Level.predefinedLevelsCache_) {
    goog.log.Level.createPredefinedLevelsCache_();
  }
  if (value in goog.log.Level.predefinedLevelsCache_) {
    return goog.log.Level.predefinedLevelsCache_[value];
  }
  for (var i = 0; i < goog.log.Level.PREDEFINED_LEVELS.length; ++i) {
    var level = goog.log.Level.PREDEFINED_LEVELS[i];
    if (level.value <= value) {
      return level;
    }
  }
  return null;
};
var goog$log$log$classdecl$var1 = function() {
};
goog$log$log$classdecl$var1.prototype.getName = function() {
};
goog.log.Logger = goog$log$log$classdecl$var1;
goog.log.Logger.Level = goog.log.Level;
var goog$log$log$classdecl$var2 = function(capacity) {
  this.capacity_ = typeof capacity === "number" ? capacity : goog.log.LogBuffer.CAPACITY;
  this.buffer_;
  this.curIndex_;
  this.isFull_;
  this.clear();
};
goog$log$log$classdecl$var2.prototype.addRecord = function(level, msg, loggerName) {
  if (!this.isBufferingEnabled()) {
    return new goog.log.LogRecord(level, msg, loggerName);
  }
  var curIndex = (this.curIndex_ + 1) % this.capacity_;
  this.curIndex_ = curIndex;
  if (this.isFull_) {
    var ret = this.buffer_[curIndex];
    ret.reset(level, msg, loggerName);
    return ret;
  }
  this.isFull_ = curIndex == this.capacity_ - 1;
  return this.buffer_[curIndex] = new goog.log.LogRecord(level, msg, loggerName);
};
goog$log$log$classdecl$var2.prototype.forEachRecord = function(func) {
  var buffer = this.buffer_;
  if (!buffer[0]) {
    return;
  }
  var curIndex = this.curIndex_;
  var i = this.isFull_ ? curIndex : -1;
  do {
    i = (i + 1) % this.capacity_;
    func(buffer[i]);
  } while (i !== curIndex);
};
goog$log$log$classdecl$var2.prototype.isBufferingEnabled = function() {
  return this.capacity_ > 0;
};
goog$log$log$classdecl$var2.prototype.isFull = function() {
  return this.isFull_;
};
goog$log$log$classdecl$var2.prototype.clear = function() {
  this.buffer_ = new Array(this.capacity_);
  this.curIndex_ = -1;
  this.isFull_ = false;
};
goog.log.LogBuffer = goog$log$log$classdecl$var2;
goog.log.LogBuffer.instance_;
goog.log.LogBuffer.CAPACITY = goog.define("goog.debug.LogBuffer.CAPACITY", 0);
goog.log.LogBuffer.getInstance = function() {
  if (!goog.log.LogBuffer.instance_) {
    goog.log.LogBuffer.instance_ = new goog.log.LogBuffer(goog.log.LogBuffer.CAPACITY);
  }
  return goog.log.LogBuffer.instance_;
};
goog.log.LogBuffer.isBufferingEnabled = function() {
  return goog.log.LogBuffer.getInstance().isBufferingEnabled();
};
var goog$log$log$classdecl$var3 = function(level, msg, loggerName, time, sequenceNumber) {
  this.level_;
  this.loggerName_;
  this.msg_;
  this.time_;
  this.sequenceNumber_;
  this.exception_ = null;
  this.reset(level || goog.log.Level.OFF, msg, loggerName, time, sequenceNumber);
};
goog$log$log$classdecl$var3.prototype.reset = function(level, msg, loggerName, time, sequenceNumber) {
  this.time_ = time || goog.now();
  this.level_ = level;
  this.msg_ = msg;
  this.loggerName_ = loggerName;
  this.exception_ = null;
  this.sequenceNumber_ = typeof sequenceNumber === "number" ? sequenceNumber : goog.log.LogRecord.nextSequenceNumber_;
};
goog$log$log$classdecl$var3.prototype.getLoggerName = function() {
  return this.loggerName_;
};
goog$log$log$classdecl$var3.prototype.setLoggerName = function(name) {
  this.loggerName_ = name;
};
goog$log$log$classdecl$var3.prototype.getException = function() {
  return this.exception_;
};
goog$log$log$classdecl$var3.prototype.setException = function(exception) {
  this.exception_ = exception;
};
goog$log$log$classdecl$var3.prototype.getLevel = function() {
  return this.level_;
};
goog$log$log$classdecl$var3.prototype.setLevel = function(level) {
  this.level_ = level;
};
goog$log$log$classdecl$var3.prototype.getMessage = function() {
  return this.msg_;
};
goog$log$log$classdecl$var3.prototype.setMessage = function(msg) {
  this.msg_ = msg;
};
goog$log$log$classdecl$var3.prototype.getMillis = function() {
  return this.time_;
};
goog$log$log$classdecl$var3.prototype.setMillis = function(time) {
  this.time_ = time;
};
goog$log$log$classdecl$var3.prototype.getSequenceNumber = function() {
  return this.sequenceNumber_;
};
goog.log.LogRecord = goog$log$log$classdecl$var3;
goog.log.LogRecord.nextSequenceNumber_ = 0;
goog.log.LogRecordHandler;
var goog$log$log$classdecl$var4 = function(name, parent) {
  parent = parent === undefined ? null : parent;
  this.level = null;
  this.handlers = [];
  this.parent = parent || null;
  this.children = [];
  this.logger = {getName:function() {
    return name;
  }};
};
goog$log$log$classdecl$var4.prototype.getEffectiveLevel = function() {
  if (this.level) {
    return this.level;
  } else {
    if (this.parent) {
      return this.parent.getEffectiveLevel();
    }
  }
  goog.asserts.fail("Root logger has no level set.");
  return goog.log.Level.OFF;
};
goog$log$log$classdecl$var4.prototype.publish = function(logRecord) {
  var target = this;
  while (target) {
    target.handlers.forEach(function(handler) {
      handler(logRecord);
    });
    target = target.parent;
  }
};
goog.log.LogRegistryEntry = goog$log$log$classdecl$var4;
var goog$log$log$classdecl$var5 = function() {
  this.entries = {};
  var rootLogRegistryEntry = new goog.log.LogRegistryEntry(goog.log.ROOT_LOGGER_NAME);
  rootLogRegistryEntry.level = goog.log.Level.CONFIG;
  this.entries[goog.log.ROOT_LOGGER_NAME] = rootLogRegistryEntry;
};
goog$log$log$classdecl$var5.prototype.getLogRegistryEntry = function(name, level) {
  var entry = this.entries[name];
  if (entry) {
    if (level !== undefined) {
      entry.level = level;
    }
    return entry;
  } else {
    var lastDotIndex = name.lastIndexOf(".");
    var parentName = name.substr(0, lastDotIndex);
    var parentLogRegistryEntry = this.getLogRegistryEntry(parentName);
    var logRegistryEntry = new goog.log.LogRegistryEntry(name, parentLogRegistryEntry);
    this.entries[name] = logRegistryEntry;
    parentLogRegistryEntry.children.push(logRegistryEntry);
    if (level !== undefined) {
      logRegistryEntry.level = level;
    }
    return logRegistryEntry;
  }
};
goog$log$log$classdecl$var5.prototype.getAllLoggers = function() {
  var $jscomp$this = this;
  return Object.keys(this.entries).map(function(loggerName) {
    return $jscomp$this.entries[loggerName].logger;
  });
};
goog.log.LogRegistry = goog$log$log$classdecl$var5;
goog.log.LogRegistry.getInstance = function() {
  if (!goog.log.LogRegistry.instance_) {
    goog.log.LogRegistry.instance_ = new goog.log.LogRegistry;
  }
  return goog.log.LogRegistry.instance_;
};
goog.log.LogRegistry.instance_;
goog.log.getLogger = function(name, level) {
  if (goog.log.ENABLED) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(name, level);
    return loggerEntry.logger;
  } else {
    return null;
  }
};
goog.log.getRootLogger = function() {
  if (goog.log.ENABLED) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(goog.log.ROOT_LOGGER_NAME);
    return loggerEntry.logger;
  } else {
    return null;
  }
};
goog.log.addHandler = function(logger, handler) {
  if (goog.log.ENABLED && logger) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(logger.getName());
    loggerEntry.handlers.push(handler);
  }
};
goog.log.removeHandler = function(logger, handler) {
  if (goog.log.ENABLED && logger) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(logger.getName());
    var indexOfHandler = loggerEntry.handlers.indexOf(handler);
    if (indexOfHandler !== -1) {
      loggerEntry.handlers.splice(indexOfHandler, 1);
      return true;
    }
  }
  return false;
};
goog.log.setLevel = function(logger, level) {
  if (goog.log.ENABLED && logger) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(logger.getName());
    loggerEntry.level = level;
  }
};
goog.log.getLevel = function(logger) {
  if (goog.log.ENABLED && logger) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(logger.getName());
    return loggerEntry.level;
  }
  return null;
};
goog.log.getEffectiveLevel = function(logger) {
  if (goog.log.ENABLED && logger) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(logger.getName());
    return loggerEntry.getEffectiveLevel();
  }
  return goog.log.Level.OFF;
};
goog.log.isLoggable = function(logger, level) {
  if (goog.log.ENABLED && logger && level) {
    return level.value >= goog.log.getEffectiveLevel(logger).value;
  }
  return false;
};
goog.log.getAllLoggers = function() {
  if (goog.log.ENABLED) {
    return goog.log.LogRegistry.getInstance().getAllLoggers();
  }
  return [];
};
goog.log.getLogRecord = function(logger, level, msg, exception) {
  var logRecord = goog.log.LogBuffer.getInstance().addRecord(level || goog.log.Level.OFF, msg, logger.getName());
  if (exception) {
    logRecord.setException(exception);
  }
  return logRecord;
};
goog.log.publishLogRecord = function(logger, logRecord) {
  if (goog.log.ENABLED && logger && goog.log.isLoggable(logger, logRecord.getLevel())) {
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(logger.getName());
    loggerEntry.publish(logRecord);
  }
};
goog.log.log = function(logger, level, msg, exception) {
  if (goog.log.ENABLED && logger && goog.log.isLoggable(logger, level)) {
    level = level || goog.log.Level.OFF;
    var loggerEntry = goog.log.LogRegistry.getInstance().getLogRegistryEntry(logger.getName());
    if (typeof msg === "function") {
      msg = msg();
    }
    var logRecord = goog.log.LogBuffer.getInstance().addRecord(level, msg, logger.getName());
    if (exception) {
      logRecord.setException(exception);
    }
    loggerEntry.publish(logRecord);
  }
};
goog.log.error = function(logger, msg, exception) {
  if (goog.log.ENABLED && logger) {
    goog.log.log(logger, goog.log.Level.SEVERE, msg, exception);
  }
};
goog.log.warning = function(logger, msg, exception) {
  if (goog.log.ENABLED && logger) {
    goog.log.log(logger, goog.log.Level.WARNING, msg, exception);
  }
};
goog.log.info = function(logger, msg, exception) {
  if (goog.log.ENABLED && logger) {
    goog.log.log(logger, goog.log.Level.INFO, msg, exception);
  }
};
goog.log.fine = function(logger, msg, exception) {
  if (goog.log.ENABLED && logger) {
    goog.log.log(logger, goog.log.Level.FINE, msg, exception);
  }
};

//# sourceMappingURL=goog.log.log.js.map
