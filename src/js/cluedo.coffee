# cluedo.js, the workhorse behind SCP-5000
# Written by Croquembouche, released under MIT

###
For cluedo, the blacklist mechanism has been removed.
Event cancellation will not be needed for cluedo.
For maitreya, where event cancellation is needed, it will need to be
reimplemented pending a re-think of how the mechanism should work.
###

"use strict"

### global $, angular ###

assert = (condition, message) ->
  unless condition
    throw new Error(message ? "AssertionError")

# randomise an array
shuffle = (array) ->
  m = array.length
  t = undefined
  i = undefined
  while m
    i = Math.floor(Math.random() * m--)
    t = array[m]
    array[m] = array[i]
    array[i] = t
  return array

do ->

  MaitreyaController = ($scope, $timeout, $sce, $http) ->
    aic = this

    $scope.trustAsHtml = (string) ->
      $sce.trustAsHtml string

    aic.lang = {} # All strings that aren't dialogue
    aic.events = {} # All events

    aic.typingDelay = 0.3
    aic.typingSpeed = 0.04 # seconds per letter
    aic.wipeTimer = false # timer for hard wiping
    aic.timeOutList = {}
    aic.isSpeaking = {}
    aic.isProcessing = {}
    ## XXX what actually is the difference between isSpeaking and isProcessing?
    # theory: speaking is for characters, processing is for the player
    # if true: "processing" should just be the speaking for the player
    # character
    aic.notifications = {}
    aic.timers = {} # holds special timers for events and the like
    aic.chatLog = {} # should be added to in reverse order
    aic.currentDialogue = []
    aic.vars = {}

    # Initial setup for once the page has loaded
    $(document).ready ->
      aic.onMobile = $('body').width() < 700
      $scope.$apply ->
        aic = aic_init(aic) # from init.js
        aic.lang = get_lang(aic) # from lang.js
        aic.events = get_events() # from events.js
      console.log "Ready to go"

    # called when "BOOT UP" is clicked from preload
    aic.bootUp = =>
      console.log "Booting up..."
      aic.preload = false
      # Here we go boys
      aic.start[0] aic.start[1], aic.start[2]
      return null

    execute_event = (event_name) ->
      # Function for executing a single event.
      console.log "Event: #{event_name}"
      event = aic.events['event_name']

      # Work out which of the lines have options.
      lines = []
      for line in event['lines']
        options = []
        for option in line['options']
          conditions = []
          for condition in option['conditions']
            conditions.push condition()
          options.push conditions.every((v) => v is true)
        if options.every((v) => v is true) then lines.push line
      # lines is now all the lines that will appear
      # write the lines, one by one, and display options of the final
      writeDialogue event_name, lines

    ### PROCESSING FUNCTIONS ###

    # pass options to chatLog for presentation to the user
    presentOptions = (line) ->
      # present the options for this line

      # options list may not be empty:
      aic.chatLog[conversation].options = []
      # if ids is "CLEAR", stop here, we only want to clear the array
      if line is 'CLEAR'
        return null

      #$scope.$apply(() ->
      aic.chatLog[conversation].options = line['options']
      #)

    # structure dialogue and calculate timing
    # writeDialogue = (conversation, dialogueList, speaker, event_name) ->
    writeDialogue = (event_name, lines) ->
      ## An event is a list of lines
      event = aic.events['event_name']
      conversation = event['conversation']
      messages = []
      totalDelay = 0
      # emote = undefined
      for line in lines
        delay = line['delay']
        duration = line['duration']
        if delay is 'auto' then delay = aic.typingDelay
        if duration is 'auto' then duration = aic.typingSpeed * line['text'].length
        assert typeof delay is 'number' and typeof duration is 'number'
        ## XXX check that opinion is propagated, may have just deleted the logic
        # obviously maitreya also always speaks instantly
        # correction: maitreya does not speak instantly, because that fucking sucks
        ## TODO XXX TODO XXX TODO change 'maitreya' to 'player' or similar
        if speaker is 'maitreya'
          # but we want the first message to be instant
          if i is 0 then duration = 0
          else if duration > 1
            # and then make her speak a little bit faster anyway
            duration *= 0.5

        if aic.cheats.impatientMode
          delay = 0
          duration = 0.1 # if 0 then messages appear in wrong order
        mode = 'default'
        if 'typed' in line['style']
          mode = 'typing'
          duration *= 2
        ## TODO alex's emotions are not css classes (ng-src):
        # if speaker == 'alexandra' and text.length > 0
        #   if !!/(^\w*?):/.exec(text)
        #     emote = /(^\w*?):/.exec(text)[1]
        #     if !aic.alexandraEmotionList.includes(emote)
        #       throw new Error("Alexandra is experiencing an invalid emotion: #{emote}")
        #     text = text.substring(emote.length + 1)
        #   else
        #     # if no emotion is specified, maintain the last one, or default
        #     emote = emote ? aic.alexandraEmotionList[0]
        messages.push {
          delay: delay
          duration: duration
          # speaker: force ? speaker
          # cssClass: cssClass # deprecated in favour of line['style']
          # text: line['text'].wikidot_format()
          # mode: mode ? 'default' # TODO mode can be a class, html pickup
          # emote: emote
          line: line
        }
        totalDelay += delay + duration
        # record the previous speaker, but only if there was actually a message
        if text.length > 0
          aic.vars.lastSpeaker = event['conversation']
      pushToLog event_name, messages
      # the total length of all messages gets passed back to the mainloop
      return totalDelay

    # push dialogue to chatLog for presentation to the user
    #pushToLog = (conversation, messages, ID, thread) ->
    pushToLog = (event_name, messages) ->
      # messages: a list of dicts:
        # delay: time before message, int, seconds
        # duration: time before message with indicator, int, seconds
        # line: the line of this message, dict

      # pushToLog is recursive: processes the first message only

      event = aic.events['event_name']
      conversation = event['conversation']

      delay = messages[0]['delay']
      duration = messages[0]['duration']

      timeOut1 = $timeout((->
        aic.timeOutList[conversation].remove(timeOut1)

        if duration > 0
          # we only want to trigger the wait at all if duration > 0
          if messages[0][2].speaker is 'maitreya' and messages.length > 0
            aic.isProcessing[conversation] = true
          else
            aic.isSpeaking[conversation] = true
            aic.isProcessing[conversation] = false
            # check to see whether breach is speaking or typing
            if messages[0][2].speaker is 'breach'
              aic.vars.breachEntryMode = messages[0][2].mode or 'speaking'
        timeOut2 = $timeout((->
          aic.timeOutList[conversation].remove(timeOut2)
          # now we need to check to see if any other messages are still coming through (HINT: they shouldn't be, but just in case)
          if aic.timeOutList[conversation].length is 0
            aic.isSpeaking[conversation] = false
            # check if the next message is ours for marker smoothness
            if messages.length > 1
              if messages[1][2].speaker is not 'maitreya'
                aic.isProcessing[conversation] = false
              # XXX so this is making the processing icon hang for a moment after maitreya's last message
              # I have no clue why it's doing this
              # correction: it actually hangs until the next message comes through. this is a problem
              # this would be because we don't force terminate it at the end of the dialogue?
            else
              aic.isProcessing[conversation] = false
              # this fixes the above
          if messages[0][2].text.length > 0
            # don't push the message if it's empty

            aic.chatLog[conversation].log.unshift messages[0][2]
            addNotification conversation

          messages.shift()
          if messages.length > 0
            # send the next message
            pushToLog event_name, messages
          else
            # no more messages. we're done here
            aic.isProcessing[conversation] = false # just in case!

        ), duration * 1000, true)
        aic.timeOutList[conversation].push timeOut2
      ), delay * 1000, true)
      aic.timeOutList[conversation].push timeOut1

    return null

  EncodeURIComponentFilter = ->
    return window.encodeURIComponent

  maitreya = angular
    .module("maitreya", ['ngSanitize', 'ngAnimate'])
    .controller("MaitreyaController",
                ['$scope', '$timeout', '$sce', '$http', MaitreyaController])
    .filter("encode", [EncodeURIComponentFilter])

  return null

# prototype functuon to turn kebab-case to camelCase
String::toCamelCase = ->
  this.toLowerCase()
    .replace(/[^\w\s\-]/g, "")
    .replace(/[^a-z0-9]/g, " ")
    .replace(/^\s+|\s+$/g, "")
    .replace(/\s(.)/g, (match, group) -> group.toUpperCase())

# prototype function to format dialogue strings from wikidot format to HTML

String::wikidot_format = ->
  # pass article argument only if this is an article
  this.replace(/\|\|\|\||\n/g, "<br>")
    .replace(/\*\*(.*?)\*\*/g, "<b>$1</b>")
    .replace(/\/\/(.*?)\/\//g, "<i>$1</i>")
    .replace(/{{(.*?)}}/g, "<tt>$1</tt>")
    .replace(/\^\^(.*?)\^\^/g, "<sup>$1</sup>")
    # .replace(/\?\?(.*?)\?\?/g, "<span dynamic class=\'statement false\' data-bool=\'TRUE\'>$1</span>")
    # .replace(/!!(.*?)!!/g, "<span class=\'statement true\' data-bool=\'FALSE\'>$1</span>")
    .replace(/^-{3,}$/g, "<hr>")
    .replace(/--/g, "—")
    .replace(/^=\s(.*)$/g, "<div style='text-align: center;'>$1</div>")
    .replace(/(>|^)\!\s([^<]*)/g, "$1<div class='fake-title'>$2</div>")
    .replace(/(>|^)\+{3}\s([^<]*)/g, "$1<h3>$2</h3>")
    .replace(/(>|^)\+{2}\s([^<]*)/g, "$1<h2>$2</h2>")
    .replace(/(>|^)\+{1}\s([^<]*)/g, "$1<h1>$2</h1>")
    .replace(/<([\w\s])|(.*?)>/g, "<span class='$1'>$2</span>")
    .replace(/^\[\[IMAGE\]\]\s([^\s]*)\s(.*)$/g, "<div class=\'scp-image-block block-right\'><img src=\'$1\'><div class=\'scp-image-caption\'><p>$2</p></div></div>")
    .replace /\[{3}(.*?)\|(.*?)\]{3}/, (match, article, text) ->
      # please ready your butts for the single worst line of code I have ever written
      angular.element(document.documentElement).scope().aic.lang.articles[article].available = true
      return "<span class=\'article-link\'>#{text}</span>"

Array::remove = (thing) ->
  index = array.indexOf thing
  if index > -1
      array.splice index, 1
