#ifndef __MIDIMOCK_H_
#define __MIDIMOCK_H_

#include <m_pd.h>
#include <semaphore.h>
#include <stdbool.h>

#define BUFFER_LEN 500

//  Note: the first note value will be invalid (-1) because this way the tick index
// can be aligned with the note/velocity index corresponding to the tick at which
// that note/velocity was recorded.
typedef struct _midibuffer {
    // TODO: Maybe store this as in integer and convert it when added
    t_float note[BUFFER_LEN];
    t_float velocity[BUFFER_LEN];
    ulong time[BUFFER_LEN];
    // index of the first free slot
    uint index;
} t_midibuffer;

typedef struct _inputs {
    t_float listen;
    t_float loop;
    t_float note;
    t_float velocity;
    // The tick period in ms
    t_float tick_ms;
} t_inputs;

typedef struct _midimock {
    char obj[48];
    t_midibuffer buffer;
    t_midibuffer note_on_buffer;
    t_inputs in_current;
    t_inputs in_previous;
    t_outlet *note_out, *velocity_out;
    t_outlet *loop_time;
    // the index in the buffer that we are next going to play from
    uint playback_index;
    ulong playback_period_ms;
    // The time the object started (unix time in ms)
    ulong start_time_ms;
    ulong playback_start_time_ms;
    // The last time the bang function was called relative to playback_start_time_ms
    ulong previous_bang_time;
    ulong playback_iteration;
} t_midimock;

bool bar(int);

void midimock_bang(t_midimock* obj);
void midimock_float(t_midimock* obj, t_floatarg f);

#endif // __MIDIMOCK_H_
