"use strict";

var aic_init;

aic_init = function aic_init(aic) {
  console.log("Initialising variables"); // The following variables can be modified for testing, but must be reset

  aic.preload = true; // MUST BE TRUE
  // The following variable determines what the initial event is

  aic.start = 'wake_up'; // The following variables can be changed to make adjustments

  aic.typingDelay = 0.0;
  aic.typingSpeed = 0.0; // seconds per letter
  // The following variables will be preserved on save/load

  aic.vars = {
    know_green_id: false,
    chosen_method: null
  }; // The following variables should not be changed

  aic.conversations = ['default'];
  aic.murder_methods = ['car', 'vase', 'bl', 'bear', 'pizza', 'choke'];
  aic.murder_locations = ['corridor', 'cafeteria', 'containment', 'study', 'office', 'carpark'];
  aic.greens = ['barry', 'gary'];
  aic.vars['green'] = aic.greens.sample();
  aic.vars['chars'] = ['blood', 'clem', 'ochre', aic.vars['green'], 'sky', 'plum']; // TODO valid combinations

  aic.vars['murder_method'] = aic.murder_methods.sample();
  aic.vars['murder_location'] = aic.murder_locations.sample();
  aic.vars['murder_person'] = aic.vars['chars'].sample();
  aic.config['clear_log_between_events'] = true;
  aic.config['add_to_log_in_reverse_order'] = false;
  aic.config['default_option_name'] = aic.lang['default_option_name'];
  aic.config['default_option_class'] = ["plum"];
  aic.config['empty_option_proceeds_immediately'] = false;
  console.log("Done initialising variables");
  return aic;
};