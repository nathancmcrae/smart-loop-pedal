# Smart Loop Pedal

This will be a MIDI loop pedal object for Pure Data

Intended operation is:
1. Press loop pedal
  - PD object will begin checking for loops in the performance
2. Once a loop has been detected, SLP will signal so
3. On pedal release (or maybe press different pedal? before releasing somehow), SLP will seamlessly begin playing the loop back
  - You should be able to cancel a loop. Maybe you could find a pedal with toe-heel actions so you can press-toe:start-listening, press-heel:cancel, release-toe:start-looping? 
