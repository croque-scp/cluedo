"use strict";

var aic_init;

aic_init = function aic_init(aic) {
  console.log("Initialising variables"); // The following variables can be modified for testing, but must be reset

  aic.preload = true; // MUST BE TRUE
  // The following variable determines what the initial event is

  aic.start = 'wake_up'; // The following variables can be changed to make adjustments

  aic.typingDelay = 0.1;
  aic.typingSpeed = 0.0; // seconds per letter
  // TODO make these 0, probably
  // The following variables will be preserved on save/load

  aic.vars = {
    know_green_id: false,
    chosen_method: null
  }; // The following variables should not be changed

  aic.wipe_between_events = true;
  aic.conversations = ['default'];
  aic.murder_methods = ["car", "vase", "bl", "bear", "pizza", "choke"];
  aic.vars['murder_method'] = aic.murder_methods.sample();
  aic.config['clear_log_between_events'] = true;
  aic.config['add_to_log_in_reverse_order'] = false;
  console.log("Done initialising variables");
  return aic;
};