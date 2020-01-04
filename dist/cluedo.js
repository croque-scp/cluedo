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
    hasProp = {}.hasOwnProperty,
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
    var aic, auto, execute_event, presentOptions, _pushToLog, speech, writeDialogue;

    aic = this;
    LoopService.use($scope); // give BreachLoopService our scope
    // the LoopService service (from LoopService.js) contains the interactions for Breach, Alexandra and D-Class generated from the spreadsheet

    $scope.trustAsHtml = function (string) {
      return $sce.trustAsHtml(string);
    };

    aic.bootDate = new Date(new Date(Date.now()).setFullYear(2018));
    auto = 'auto';
    aic.lang = {}; // This object contains all strings that aren't dialogue

    speech = {
      // This object contains all dialogue strings
      merge: function merge(dialogue) {
        var bigSection, section, speaker; // merges dialogue from LoopService into this variable

        console.log("Merging dialogue...");

        for (bigSection in dialogue) {
          if (!hasProp.call(dialogue, bigSection)) continue;
          section = dialogue[bigSection];

          if (this.hasOwnProperty(bigSection)) {
            for (speaker in section) {
              if (!hasProp.call(section, speaker)) continue;
              console.log("..." + bigSection + " of " + speaker);
              this[bigSection][speaker] = dialogue[bigSection][speaker];
            }
          } else {
            // if speech does not have the bigSection, hell yeah let's
            // overwrite that shit
            console.log("...new " + bigSection);
            this[bigSection] = dialogue[bigSection];
          }
        }

        return null;
      }
    };
    aic.typingDelay = 0.3;
    aic.typingSpeed = 0.04; // seconds per letter

    aic.wipeTimer = false; // timer for hard wiping

    aic.timeOutList = {};
    aic.isSpeaking = {};
    aic.isProcessing = {};
    aic.notifications = {};
    aic.timers = {}; // holds special timers for events and the like

    aic.chatLog = {}; // should be added to in reverse order

    aic.currentDialogue = [];
    aic.vars = {}; // Initial setup for once the page has loaded

    $(document).ready(function () {
      aic.onMobile = $('body').width() < 700;
      $scope.$apply(function () {
        aic = aic_init(aic); // from init.js

        aic.lang = getBaseLexicon(aic)['lang'];
        speech.merge(getBaseLexicon(aic)['speech']);
        return speech.merge(LoopService.dialogue);
      });
      preloadImage(aic.lang.images.greyStripe);
      console.log("Ready to go");
      return null;
    }); // called when "BOOT UP" is clicked from preload

    aic.bootUp = function () {
      console.log("Booting up...");
      aic.preload = false; // Here we go boys

      aic.start[0](aic.start[1], aic.start[2]);
      return null;
    };

    aic.mainLoop = function (event_name) {
      // TODO add character/sheet property to events
      event_name = event_name.replace(/_*$/g, "");
      console.log("Event = " + event_name);

      if (event_name in aic.events) {
        return execute_event(aic.events[event_name]);
      } else {
        throw new Error(event_name + " is not an event");
      }
    };

    execute_event = function execute_event(event_name) {
      var condition, conditions, event, j, k, l, len, len1, len2, line, lines, option, options, ref, ref1, ref2; // Function for executing a single event.

      console.log("Event: " + event_name);
      event = aic.getEvents()['event_name']; // Work out which of the lines have options.

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
            conditions.push(condition());
          }

          options.push(conditions.every(function (v) {
            return v === true;
          }));
        }

        if (options.every(function (v) {
          return v === true;
        })) {
          lines.push(line);
        }
      } // lines is now all the lines that will appear
      // write the lines, one by one, and display options of the final


      return render_lines(event_name, lines);
    };
    /* PROCESSING FUNCTIONS */
    // pass options to chatLog for presentation to the user


    presentOptions = function presentOptions(line) {
      // present the options for this line
      // options list may not be empty:
      aic.chatLog[conversation].options = []; // if ids is "CLEAR", stop here, we only want to clear the array

      if (line === 'CLEAR') {
        return null;
      } //$scope.$apply(() ->


      return aic.chatLog[conversation].options = line['options'];
    }; //)
    // structure dialogue and calculate timing
    // writeDialogue = (conversation, dialogueList, speaker, event_name) ->


    writeDialogue = function writeDialogue(event) {
      var delay, duration, j, len, line, messages, mode, ref, speaker, totalDelay; //# An event is a list of lines

      speaker = event['speaker']; // event_name is not always present, but we need it
      // it may be "undefined", deal with that later
      // deep copy the dialogue to protect the original

      messages = [];
      totalDelay = 0;
      ref = event['lines']; // emote = undefined

      for (j = 0, len = ref.length; j < len; j++) {
        line = ref[j];
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

        if (speaker === 'maitreya') {
          // but we want the first message to be instant
          if (i === 0) {
            duration = 0;
          } else if (duration > 1) {
            // and then make her speak a little bit faster anyway
            duration *= 0.5;
          }
        }

        if (aic.cheats.impatientMode) {
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
          mode: mode != null ? mode : 'default',
          // emote: emote
          line: line
        });
        totalDelay += delay + duration; // record the previous speaker, but only if there was actually a message

        if (text.length > 0) {
          aic.vars.lastSpeaker = event['speaker'];
        }
      }

      _pushToLog(event_name, messages); // the total length of all messages gets passed back to the mainloop


      return totalDelay;
    }; // push dialogue to chatLog for presentation to the user
    //pushToLog = (conversation, messages, ID, thread) ->


    _pushToLog = function pushToLog(event_name, messages) {
      var delay, duration, event, timeOut1; // messages: a list of dicts:
      // delay: time before message, int, seconds
      // duration: time before message with indicator, int, seconds
      // line: the line of this message, dict
      // pushToLog is recursive: processes the first message only

      event = getEvents()['event_name'];
      delay = messages[0]['delay'];
      duration = messages[0]['duration'];
      timeOut1 = $timeout(function () {
        var timeOut2;
        aic.timeOutList[event['speaker']].remove(timeOut1);

        if (duration > 0) {
          // we only want to trigger the wait at all if duration > 0
          if (messages[0][2].speaker === 'maitreya' && messages.length > 0) {
            aic.isProcessing[conversation] = true;
          } else {
            aic.isSpeaking[conversation] = true;
            aic.isProcessing[conversation] = false; // check to see whether breach is speaking or typing

            if (messages[0][2].speaker === 'breach') {
              aic.vars.breachEntryMode = messages[0][2].mode || 'speaking';
            }
          }
        }

        timeOut2 = $timeout(function () {
          aic.timeOutList[event['speaker']].remove(timeOut2); // now we need to check to see if any other messages are still coming through (HINT: they shouldn't be, but just in case)

          if (aic.timeOutList[conversation].length === 0) {
            aic.isSpeaking[conversation] = false; // check if the next message is ours for marker smoothness

            if (messages.length > 1) {
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


          if (messages[0][2].text.length > 0) {
            // don't push the message if it's empty
            aic.chatLog[conversation].log.unshift(messages[0][2]);
            addNotification(conversation);
          }

          messages.shift();

          if (messages.length > 0) {
            // send the next message
            return _pushToLog(event_name, messages);
          } else {
            // no more messages. we're done here
            return aic.isProcessing[conversation] = false; // just in case!
          }
        }, duration * 1000, true);
        return aic.timeOutList[conversation].push(timeOut2);
      }, delay * 1000, true);
      return aic.timeOutList[conversation].push(timeOut1);
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
  // .replace(/\?\?(.*?)\?\?/g, "<span dynamic class=\'statement false\' data-bool=\'TRUE\'>$1</span>")
  // .replace(/!!(.*?)!!/g, "<span class=\'statement true\' data-bool=\'FALSE\'>$1</span>")
  return this.replace(/\|\|\|\||\n/g, "<br>").replace(/\*\*(.*?)\*\*/g, "<b>$1</b>").replace(/\/\/(.*?)\/\//g, "<i>$1</i>").replace(/{{(.*?)}}/g, "<tt>$1</tt>").replace(/\^\^(.*?)\^\^/g, "<sup>$1</sup>").replace(/^-{3,}$/g, "<hr>").replace(/--/g, "—").replace(/^=\s(.*)$/g, "<div style='text-align: center;'>$1</div>").replace(/(>|^)\!\s([^<]*)/g, "$1<div class='fake-title'>$2</div>").replace(/(>|^)\+{3}\s([^<]*)/g, "$1<h3>$2</h3>").replace(/(>|^)\+{2}\s([^<]*)/g, "$1<h2>$2</h2>").replace(/(>|^)\+{1}\s([^<]*)/g, "$1<h1>$2</h1>").replace(/<([\w\s])|(.*?)>/g, "<span class='$1'>$2</span>").replace(/^\[\[IMAGE\]\]\s([^\s]*)\s(.*)$/g, "<div class=\'scp-image-block block-right\'><img src=\'$1\'><div class=\'scp-image-caption\'><p>$2</p></div></div>").replace(/\[{3}(.*?)\|(.*?)\]{3}/, function (match, article, text) {
    // please ready your butts for the single worst line of code I have ever written
    angular.element(document.documentElement).scope().aic.lang.articles[article].available = true;
    return "<span class='article-link'>" + text + "</span>";
  });
};

Array.prototype.remove = function (thing) {
  var index;
  index = array.indexOf(thing);

  if (index > -1) {
    return array.splice(index, 1);
  }
};