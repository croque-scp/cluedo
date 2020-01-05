"use strict";

var aic_init;

aic_init = function aic_init(aic) {
  console.log("Initialising variables"); // The following variables can be modified for testing, but must be reset

  aic.preload = true; // MUST BE TRUE
  // The following variable determines what the initial event is

  aic.start = 'wake_up'; // The following variables can be changed to make adjustments

  aic.typingDelay = 0.1;
  aic.typingSpeed = 0.04; // seconds per letter
  // TODO make these 0, probably
  // The following variables will be preserved on save/load

  aic.vars = {
    green: "",
    know_green_id: false,
    hosen_method: "",
    murder_method: "",
    murder_location: "",
    murder_person: ""
  }; // The following variables should not be changed

  aic.wipe_between_events = true;
  aic.conversations = ['default'];
  console.log("Done initialising variables");
  return aic;
};