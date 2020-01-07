// cluedo.js, the workhorse behind SCP-5000
// Written by Croquembouche, released under MIT

/*
For cluedo, the blacklist mechanism has been removed.
Event cancellation will not be needed for cluedo.
For maitreya, where event cancellation is needed, it will need to be
reimplemented pending a re-think of how the mechanism should work.
*/
"use strict";
/* global $, angular */

var assert,
    shuffle,
    indexOf = [].indexOf;

assert = function assert(condition, message) {
  if (!condition) {
    throw new Error(message != null ? message : "AssertionError");
  }
}; // randomise an array


shuffle = function shuffle(array) {
  var i, m, t;
  m = array.length;
  t = void 0;
  i = void 0;

  while (m) {
    i = Math.floor(Math.random() * m--);
    t = array[m];
    array[m] = array[i];
    array[i] = t;
  }

  return array;
};

(function () {
  var EncodeURIComponentFilter, MaitreyaController, maitreya;

  MaitreyaController = function MaitreyaController($scope, $timeout, $sce, $http) {
    var aic, _pushToLog, writeDialogue;

    aic = this; // Change these settings in init.coffee

    aic.config = {
      // Should the whole message log be wiped between events, or should the
      // user be able to see all messages?
      clear_log_between_events: false,
      // Should the message log be in reverse? Useful with `flex-direction:
      // column-reverse` for making a terminal-like UI
      add_to_log_in_reverse_order: true,
      // If an option's text is `null`, and it is the only option that would be
      // presented, should the next event happen automatically?
      empty_option_proceeds_immediately: true,
      // If the above is false, if an option's text is `null`, what should it
      // appear as to the user?
      default_option_name: "Undefined option",
      // If the above is false, if an option's text is `null` and it has no CSS
      // class, what should its class be? (list of strings)
      default_option_class: []
    };

    $scope.trustAsHtml = function (string) {
      return $sce.trustAsHtml(string);
    };

    aic.lang = {}; // All strings that aren't dialogue

    aic.events = {}; // All events

    aic.typingDelay = 0.3;
    aic.typingSpeed = 0.04; // seconds per letter

    aic.wipeTimer = false; // timer for hard wiping

    aic.timeOutList = [];
    aic.isSpeaking = {};
    aic.isProcessing = {}; //# XXX what actually is the difference between isSpeaking and isProcessing?
    // theory: speaking is for characters, processing is for the player
    // if true: "processing" should just be the speaking for the player
    // character

    aic.notifications = {};
    aic.timers = {}; // holds special timers for events and the like

    aic.currentDialogue = [];
    aic.vars = {};
    aic.cheats = {}; // possibly merge with vars

    aic.start = null;
    aic.preload = true;
    aic.chatLog = {
      log: [],
      options: []
    }; // Initial setup for once the page has loaded

    $(document).ready(function () {
      aic.onMobile = $('body').width() < 700;
      $scope.$apply(function () {
        aic.lang = get_lang(aic); // from lang.js

        aic.events = get_events(); // from events.js

        return aic = aic_init(aic); // from init.js
      });
      console.log("Ready to go");
      return aic.bootUp(); // XXX TEMPORARY
    }); // called when "BOOT UP" is clicked from preload

    aic.bootUp = function () {
      console.log("Booting up...");
      aic.preload = false; // Here we go boys

      return aic.execute_event(aic.start);
    };

    aic.execute_event = function (event_name) {
      var condition, conditions, event, j, k, l, len, len1, len2, line, lines, option, options, ref, ref1, ref2; // Function for executing a single event.

      console.log("Event: " + event_name);
      event = aic.events[event_name]; // clear the options for this conversation

      assert(event != null, event_name + " doesn't exist"); // Work out which of the lines have options.

      lines = [];
      ref = event['lines'];

      for (j = 0, len = ref.length; j < len; j++) {
        line = ref[j];
        options = [];
        ref1 = line['options'];

        for (k = 0, len1 = ref1.length; k < len1; k++) {
          option = ref1[k];
          conditions = [];
          ref2 = option['conditions'];

          for (l = 0, len2 = ref2.length; l < len2; l++) {
            condition = ref2[l];
            conditions.push(condition(aic));
          }

          options.push(conditions.every(function (v) {
            return v === true;
          }));
        }

        if (options.some(function (v) {
          return v === true;
        })) {
          lines.push(line);
        }
      } // lines is now all the lines that will appear
      // If the option is given, clear the message log


      if (aic.config['clear_log_between_events']) {
        aic.chatLog.log = aic.chatLog.log.filter(function (line) {
          return line['conversation'] !== event['conversation'];
        });
      } // Execute any precommands


      event['precommand'](aic); // write the lines, one by one, and display options of the final

      writeDialogue(event_name, lines); // Execute any postcommands

      return event['postcommand'](aic);
    };
    /* PROCESSING FUNCTIONS */
    // pass options to chatLog for presentation to the user


    aic.present_options = function (event_name, line) {
      var event, j, len, option, option_modifier, ref, ref1, results; // present the options for this line

      event = aic.events[event_name]; // options list may not be empty:

      aic.chatLog.options = aic.chatLog.options.filter(function (option) {
        return option['conversation'] !== event['conversation'];
      }); // if ids is "CLEAR", stop here, we only want to clear the array

      if (line === 'CLEAR') {
        return null;
      }

      ref = line['options']; // TODO skip this if option is null and skip is true
      // TODO null destination should not present options

      results = [];

      for (j = 0, len = ref.length; j < len; j++) {
        option = ref[j]; // Only options with true Appears If appears

        if (!option['conditions'].every(function (c) {
          return c(aic) === true;
        })) {
          continue;
        } // Modify the option so that it knows its context


        option_modifier = {
          event_name: event_name,
          conversation: event['conversation'],
          text: (ref1 = option['text']) != null ? ref1 : aic.lang['default_option']
        };
        results.push(aic.chatLog.options.push(Object.assign({}, option, option_modifier)));
      }

      return results;
    }; // XXX what if no options appear?


    aic.select_option = function (option) {
      var event_name; // Recieves a modified option that knows its context

      event_name = option['event_name']; // Clear remaining options for this conversation

      aic.present_options(event_name, 'CLEAR'); // Execute oncommands

      option['oncommand'](aic); // Call the next event

      return aic.execute_event(option['destination']);
    }; // structure dialogue and calculate timing
    // writeDialogue = (conversation, dialogueList, speaker, event_name) ->


    writeDialogue = function writeDialogue(event_name, lines) {
      var conversation, delay, duration, event, j, len, line, messages, mode, totalDelay; //# An event is a list of lines

      event = aic.events[event_name];
      conversation = event['conversation'];
      messages = [];
      totalDelay = 0; // emote = undefined

      for (j = 0, len = lines.length; j < len; j++) {
        line = lines[j];
        delay = line['delay'];
        duration = line['duration'];

        if (delay === 'auto') {
          delay = aic.typingDelay;
        }

        if (duration === 'auto') {
          duration = aic.typingSpeed * line['text'].length;
        }

        assert(typeof delay === 'number' && typeof duration === 'number'); //# XXX check that opinion is propagated, may have just deleted the logic
        // obviously maitreya also always speaks instantly
        // correction: maitreya does not speak instantly, because that fucking sucks
        //# TODO XXX TODO XXX TODO change 'maitreya' to 'player' or similar
        // if speaker is 'maitreya'
        //   # but we want the first message to be instant
        //   if i is 0 then duration = 0
        //   else if duration > 1
        //     # and then make her speak a little bit faster anyway
        //     duration *= 0.5

        if (aic.cheats['impatientMode']) {
          delay = 0;
          duration = 0.1; // if 0 then messages appear in wrong order
        }

        mode = 'default';

        if (indexOf.call(line['style'], 'typed') >= 0) {
          mode = 'typing';
          duration *= 2;
        } //# TODO alex's emotions are not css classes (ng-src):
        // if speaker == 'alexandra' and text.length > 0
        //   if !!/(^\w*?):/.exec(text)
        //     emote = /(^\w*?):/.exec(text)[1]
        //     if !aic.alexandraEmotionList.includes(emote)
        //       throw new Error("Alexandra is experiencing an invalid emotion: #{emote}")
        //     text = text.substring(emote.length + 1)
        //   else
        //     # if no emotion is specified, maintain the last one, or default
        //     emote = emote ? aic.alexandraEmotionList[0]


        messages.push({
          delay: delay,
          duration: duration,
          // speaker: force ? speaker
          // cssClass: cssClass # deprecated in favour of line['style']
          // text: line['text'].wikidot_format()
          // mode: mode ? 'default' # TODO mode can be a class, html pickup
          // emote: emote
          line: line
        });
        totalDelay += delay + duration;
      }

      _pushToLog(event_name, messages); // the total length of all messages gets passed back to the mainloop


      return totalDelay;
    }; // push dialogue to chatLog for presentation to the user
    //pushToLog = (conversation, messages, ID, thread) ->


    _pushToLog = function pushToLog(event_name, messages) {
      var conversation, delay, duration, event, message, timeOut1; // messages: a list of dicts:
      // delay: time before message, int, seconds
      // duration: time before message with indicator, int, seconds
      // line: the line of this message, dict
      // pushToLog is recursive: processes the first message only

      event = aic.events[event_name];
      conversation = event['conversation'];
      message = messages.shift();
      delay = message['delay'];
      duration = message['duration'];
      timeOut1 = $timeout(function () {
        var timeOut2;
        aic.timeOutList.remove(timeOut1);

        if (duration > 0) {
          // we only want to trigger the wait at all if duration > 0
          if (message['speaker'] === 'maitreya' && messages.length > 0) {
            aic.isProcessing[conversation] = true;
          } else {
            aic.isSpeaking[conversation] = true;
            aic.isProcessing[conversation] = false; // check to see whether breach is speaking or typing

            if (message['speaker'] === 'breach') {
              aic.vars.breachEntryMode = message['mode'] || 'speaking';
            }
          }
        }

        timeOut2 = $timeout(function () {
          var log, text;
          aic.timeOutList.remove(timeOut2); // now we need to check to see if any other messages are still coming through (HINT: they shouldn't be, but just in case)
          //# XXX what is this check? what does it mean?

          if (aic.timeOutList.length === 0) {
            aic.isSpeaking[conversation] = false; // check if the next message is ours for marker smoothness
            //# XXX WHAT THE FUCK IS THIS HOT MESS

            if (messages.length > 1 && false) {
              if (messages[1][2].speaker === !'maitreya') {
                aic.isProcessing[conversation] = false;
              }
            } else {
              // XXX so this is making the processing icon hang for a moment after maitreya's last message
              // I have no clue why it's doing this
              // correction: it actually hangs until the next message comes through. this is a problem
              // this would be because we don't force terminate it at the end of the dialogue?
              aic.isProcessing[conversation] = false;
            }
          } // this fixes the above


          text = message['line']['text'];

          if (text.length > 0) {
            // don't push the message if it's empty
            log = {
              conversation: conversation,
              cssClass: message['cssClass'],
              text: text.wikidot_format()
            };

            if (aic.config['add_to_log_in_reverse_order']) {
              aic.chatLog.log.unshift(log);
            } else {
              aic.chatLog.log.push(log);
            }
          }

          if (messages.length > 0) {
            // send the next message
            return _pushToLog(event_name, messages);
          } else {
            // no more messages. we're done here
            aic.isSpeaking[conversation] = false;
            aic.isProcessing[conversation] = false; // just in case!
            // present the options from the last message

            return aic.present_options(event_name, message['line']);
          }
        }, duration * 1000, true);
        return aic.timeOutList.push(timeOut2);
      }, delay * 1000, true);
      return aic.timeOutList.push(timeOut1);
    };

    return null;
  };

  EncodeURIComponentFilter = function EncodeURIComponentFilter() {
    return window.encodeURIComponent;
  };

  maitreya = angular.module("maitreya", ['ngSanitize', 'ngAnimate']).controller("MaitreyaController", ['$scope', '$timeout', '$sce', '$http', MaitreyaController]).filter("encode", [EncodeURIComponentFilter]);
  return null;
})(); // prototype functuon to turn kebab-case to camelCase


String.prototype.toCamelCase = function () {
  return this.toLowerCase().replace(/[^\w\s\-]/g, "").replace(/[^a-z0-9]/g, " ").replace(/^\s+|\s+$/g, "").replace(/\s(.)/g, function (match, group) {
    return group.toUpperCase();
  });
}; // prototype function to format dialogue strings from wikidot format to HTML


String.prototype.wikidot_format = function () {
  // pass article argument only if this is an article
  return this.replace(/<([\w\s]*?)\|(.*?)>/gs, "<span class='$1'>$2</span>").replace(/\|\|\|\||\r\n|\r|\n/g, "<br>").replace(/\*\*(.*?)\*\*/g, "<b>$1</b>").replace(/\/\/(.*?)\/\//g, "<i>$1</i>").replace(/{{(.*?)}}/g, "<tt>$1</tt>").replace(/\^\^(.*?)\^\^/g, "<sup>$1</sup>").replace(/^-{3,}$/g, "<hr>").replace(/--/g, "—").replace(/^=\s(.*)$/g, "<div style='text-align: center;'>$1</div>").replace(/(>|^)\!\s([^<]*)/g, "$1<div class='fake-title'>$2</div>").replace(/(>|^)\+{3}\s([^<]*)/g, "$1<h3>$2</h3>").replace(/(>|^)\+{2}\s([^<]*)/g, "$1<h2>$2</h2>").replace(/(>|^)\+{1}\s([^<]*)/g, "$1<h1>$2</h1>");
};

Array.prototype.remove = function (thing) {
  var index;
  index = this.indexOf(thing);

  if (index > -1) {
    return this.splice(index, 1);
  }
};

Array.prototype.sample = function () {
  return this[Math.floor(Math.random() * this.length)];
};