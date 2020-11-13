module SeleniumWebdriver.XHR where

import Prelude
import Effect.Aff (Aff)
import Effect.Exception (error)
import Control.Monad.Error.Class (throwError)
import Control.Monad.Except (runExcept)
import Data.Either (either, Either(..))
import Foreign (isUndefined, readArray, readBoolean, readNullOrUndefined, readString)
import Foreign.Index (readProp)
import Data.Traversable (traverse, for)
import SeleniumWebdriver (executeStr)
import SeleniumWebdriver.Types (Driver, XHRStats, readMethod, readXHRState)

-- | Start spy on xhrs. It defines global variable in browser
-- | and put information about to it.
startSpying ∷ Driver → Aff Unit
startSpying driver = void $
  executeStr driver """
"use strict"
// If we have activated spying
if (window.__SELENIUM__) {
  // and it stopped
  if (!window.__SELENIUM__.isActive) {
    window.__SELENIUM__.spy();
  }
} else {
  var Selenium = {
      isActive: false,
      log: [],
      count: 0,
      spy: function() {
          // monkey patch
          var open = XMLHttpRequest.prototype.open;
          window.XMLHttpRequest.prototype.open =
              function(method, url, async, user, password) {
                  // we need this mark to update log after
                  // request is finished
                  this.__id = Selenium.count;
                  Selenium.log[this.__id] = {
                      method: method,
                      url: url,
                      async: async,
                      user: user,
                      password: password,
                      state: "stale"
                  };
                  Selenium.count++;
                  open.apply(this, arguments);
              };
          // another monkey patch
          var send = XMLHttpRequest.prototype.send;
          window.XMLHttpRequest.prototype.send =
              function(data) {
                  // this request can be deleted (this.clean() i.e.)
                  if (Selenium.log[this.__id]) {
                      Selenium.log[this.__id].state = "opened";
                  }
                  // monkey pathc `onload` (I suppose it's useless to fire xhr
                  // without `onload` handler, but to be sure there is check for
                  // type of current value
                  var m = this.onload;
                  this.onload = function() {
                      if (Selenium.log[this.__id]) {
                          Selenium.log[this.__id].state = "loaded";
                      }
                      if (typeof m == 'function') {
                          m();
                      }
                  };
                  send.apply(this, arguments);
              };
          // monkey patch `abort`
          var abort = window.XMLHttpRequest.prototype.abort;
          window.XMLHttpRequest.prototype.abort = function() {
              if (Selenium.log[this.__id]) {
                  Selenium.log[this.__id].state = "aborted";
              }
              abort.apply(this, arguments);
          };
          this.isActive = true;
          // if we define it here we need not to make `send` global
          Selenium.unspy = function() {
              this.active = false;
              window.XMLHttpRequest.send = send;
              window.XMLHttpRequest.open = open;
              window.XMLHttpRequest.abort = abort;
          };
      },
      // just clean log
      clean: function() {
          this.log = [];
      }
  };
  window.__SELENIUM__ = Selenium;
  Selenium.spy();
}
"""

-- | Return xhr's method to initial. Will not raise an error if hasn't been initiated
stopSpying ∷ Driver → Aff Unit
stopSpying driver = void $ executeStr driver """
if (window.__SELENIUM__) {
    window.__SELENIUM__.unspy();
}
"""

-- | Clean log. Will raise an error if spying hasn't been initiated
clearLog ∷ Driver → Aff Unit
clearLog driver = do
  success ← executeStr driver """
  if (!window.__SELENIUM__) {
    return false;
  }
  else {
    window.__SELENIUM__.clean();
    return true;
  }
  """
  case runExcept $ readBoolean success of
    Right true → pure unit
    _ → throwError $ error "spying is inactive"

-- | Get recorded xhr stats. If spying has not been set will raise an error
getStats ∷ Driver → Aff (Array XHRStats)
getStats driver = do
  log ← executeStr driver """
  if (!window.__SELENIUM__) {
    return undefined;
  }
  else {
    return window.__SELENIUM__.log;
  }
  """
  when (isUndefined log)
    $ throwError $ error "spying is inactive"

  either (const $ throwError $ error "incorrect log") pure $ runExcept do
    arr ← readArray log
    for arr \el → do
      state ← readXHRState =<< readProp "state" el
      method ← readMethod =<< readProp "method" el
      url ← readString =<< readProp "url" el
      async ← readBoolean =<< readProp "async" el
      password ← traverse readString =<< readNullOrUndefined =<< readProp "password" el
      user ← traverse readString =<< readNullOrUndefined =<< readProp "user" el
      pure { state: state
           , method: method
           , url: url
           , async: async
           , password: password
           , user: user
           }
