#ifndef __MIDIMOCK_H_
#define __MIDIMOCK_H_

#include <assert.h>
#include <m_pd.h>
#include <semaphore.h>
#include <stdbool.h>

#define BUFFER_LEN 500

//  Note: the first note value will be invalid (-1) because this way the tick index
// can be aligned with the note/velocity index corresponding to the tick at which
// that note/velocity was recorded.
//
// The first entry in the buffer records the tick at which listening began.
typedef struct _midibuffer {
    t_float note[BUFFER_LEN];
    t_float velocity[BUFFER_LEN];
    long tick[BUFFER_LEN];
    // index of the first free slot
    int index;
} t_midibuffer;

typedef struct _inputs {
    t_float listen;
    t_float loop;
    t_float note;
    t_float velocity;
} t_inputs;

typedef struct _midimock {
    char obj[48];
    t_midibuffer buffer;
    t_inputs in_current;
    t_inputs in_previous;
    t_outlet *note_out, *velocity_out;
    // 1 if loop is ready, 0 otherwise
    // not using this right now
    t_outlet *loop_ok_out;
    bool busy;
    // do we need to initialize this?
    long long tick;
    long long playback_tick;
    // the index in the buffer that we are next going to play from
    int playback_index;
} t_midimock;

bool bar(int);

void midimock_bang(t_midimock* obj);

#endif // __MIDIMOCK_H_
