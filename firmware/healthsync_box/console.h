// console.h — bench commands typed in the Serial Monitor (line ending
// "Newline"). Phase 3 gives the phone the same abilities over Bluetooth.
//
//   time YYYY-MM-DD HH:MM[:SS]      set the clock (Manila time)
//   add <1-6> <HH:MM> [mon,wed,...] add a dose time (every day if no days)
//   list | status                   the dose times with today's state
//   del <n>                         delete dose time n (from list)
//   clear                           delete every dose time
//   log [n] | pending | ack <seq>   the dose log (Phase 2)
//   sd                              SD card status
//   help
#pragma once

void console_begin();

// Call every loop(). Returns true when a command changed the time or the
// schedule, so the caller can refresh the LEDs at once.
bool console_update();
