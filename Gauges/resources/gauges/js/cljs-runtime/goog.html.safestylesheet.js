goog.loadModule(function(exports) {
  "use strict";
  goog.module("goog.html.SafeStyleSheet");
  goog.module.declareLegacyNamespace();
  var Const = goog.require("goog.string.Const");
  var SafeStyle = goog.require("goog.html.SafeStyle");
  var TypedString = goog.require("goog.string.TypedString");
  var googArray = goog.require("goog.array");
  var googObject = goog.require("goog.object");
  var $jscomp$destructuring$var1 = goog.require("goog.asserts");
  var assert = $jscomp$destructuring$var1.assert;
  var fail = $jscomp$destructuring$var1.fail;
  var $jscomp$destructuring$var2 = goog.require("goog.string.internal");
  var contains = $jscomp$destructuring$var2.contains;
  var CONSTRUCTOR_TOKEN_PRIVATE = {};
  var SafeStyleSheet = function(value, token) {
    this.privateDoNotAccessOrElseSafeStyleSheetWrappedValue_ = token === CONSTRUCTOR_TOKEN_PRIVATE ? value : "";
    this.implementsGoogStringTypedString = true;
  };
  SafeStyleSheet.createRule = function(selector, style) {
    if (contains(selector, "\x3c")) {
      throw new Error("Selector does not allow '\x3c', got: " + selector);
    }
    var selectorToCheck = selector.replace(/('|")((?!\1)[^\r\n\f\\]|\\[\s\S])*\1/g, "");
    if (!/^[-_a-zA-Z0-9#.:* ,>+~[\]()=^$|]+$/.test(selectorToCheck)) {
      throw new Error("Selector allows only [-_a-zA-Z0-9#.:* ,\x3e+~[\\]()\x3d^$|] and " + "strings, got: " + selector);
    }
    if (!SafeStyleSheet.hasBalancedBrackets_(selectorToCheck)) {
      throw new Error("() and [] in selector must be balanced, got: " + selector);
    }
    if (!(style instanceof SafeStyle)) {
      style = SafeStyle.create(style);
    }
    var styleSheet = selector + "{" + SafeStyle.unwrap(style).replace(/</g, "\\3C ") + "}";
    return SafeStyleSheet.createSafeStyleSheetSecurityPrivateDoNotAccessOrElse(styleSheet);
  };
  SafeStyleSheet.hasBalancedBrackets_ = function(s) {
    var brackets = {"(":")", "[":"]"};
    var expectedBrackets = [];
    for (var i = 0; i < s.length; i++) {
      var ch = s[i];
      if (brackets[ch]) {
        expectedBrackets.push(brackets[ch]);
      } else {
        if (googObject.contains(brackets, ch)) {
          if (expectedBrackets.pop() != ch) {
            return false;
          }
        }
      }
    }
    return expectedBrackets.length == 0;
  };
  SafeStyleSheet.concat = function(var_args) {
    var result = "";
    var addArgument = function(argument) {
      if (Array.isArray(argument)) {
        googArray.forEach(argument, addArgument);
      } else {
        result += SafeStyleSheet.unwrap(argument);
      }
    };
    googArray.forEach(arguments, addArgument);
    return SafeStyleSheet.createSafeStyleSheetSecurityPrivateDoNotAccessOrElse(result);
  };
  SafeStyleSheet.fromConstant = function(styleSheet) {
    var styleSheetString = Const.unwrap(styleSheet);
    if (styleSheetString.length === 0) {
      return SafeStyleSheet.EMPTY;
    }
    assert(!contains(styleSheetString, "\x3c"), "Forbidden '\x3c' character in style sheet string: " + styleSheetString);
    return SafeStyleSheet.createSafeStyleSheetSecurityPrivateDoNotAccessOrElse(styleSheetString);
  };
  SafeStyleSheet.prototype.getTypedStringValue = function() {
    return this.privateDoNotAccessOrElseSafeStyleSheetWrappedValue_;
  };
  SafeStyleSheet.unwrap = function(safeStyleSheet) {
    if (safeStyleSheet instanceof SafeStyleSheet && safeStyleSheet.constructor === SafeStyleSheet) {
      return safeStyleSheet.privateDoNotAccessOrElseSafeStyleSheetWrappedValue_;
    } else {
      fail("expected object of type SafeStyleSheet, got '" + safeStyleSheet + "' of type " + goog.typeOf(safeStyleSheet));
      return "type_error:SafeStyleSheet";
    }
  };
  SafeStyleSheet.createSafeStyleSheetSecurityPrivateDoNotAccessOrElse = function(styleSheet) {
    return new SafeStyleSheet(styleSheet, CONSTRUCTOR_TOKEN_PRIVATE);
  };
  if (goog.DEBUG) {
    SafeStyleSheet.prototype.toString = function() {
      return "SafeStyleSheet{" + this.privateDoNotAccessOrElseSafeStyleSheetWrappedValue_ + "}";
    };
  }
  SafeStyleSheet.EMPTY = SafeStyleSheet.createSafeStyleSheetSecurityPrivateDoNotAccessOrElse("");
  exports = SafeStyleSheet;
  return exports;
});

//# sourceMappingURL=goog.html.safestylesheet.js.map
