#include <assert.h>
#include <m_pd.h>
#include <stdbool.h>
#include <semaphore.h>

#define BUFFER_LEN 500

static t_class *midimock_class;

// Note: the first note value will be invalid (-1) because this way the tick index
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
    t_object obj;
    t_midibuffer buffer;
    t_inputs in_current;
    t_inputs in_previous;
    t_outlet *note_out, *vel_out;
    // 1 if loop is ready, 0 otherwise
    t_outlet *loop_ok_out;
    bool busy;
    // do we need to initialize this?
    long tick;
    long playback_tick;
    // the index in the buffer that we are next going to play from
    int playback_index;
} t_midimock;

void
midimock_bang(t_midimock* obj){
    // don't run when re-entering; not thread-safe
    //   is it even possible in PD? Isn't the bang callback run synchronously?
    if(obj->busy) return;
    obj->busy = true;
    // done with start-of-function stuff

    // If we're listening, then record the MIDI note every time the inputs change.
    if(obj->in_current.listen){
        if(!obj->in_previous.listen){
            obj->buffer.index = 0;

            obj->buffer.note[0] = -1;
            obj->buffer.velocity[0] = -1;
            obj->buffer.tick[0] = obj->tick;
        } else if(!(obj->in_current.note == obj->in_previous.note
           && obj->in_current.velocity == obj->in_previous.velocity)){
            assert(obj->buffer.index < BUFFER_LEN);

            obj->buffer.note[obj->buffer.index] = obj->in_current.note;
            obj->buffer.velocity[obj->buffer.index] = obj->in_current.velocity;
            obj->buffer.tick[obj->buffer.index] = obj->tick;

            obj->buffer.index++;
        }
    }

    // If we're looping, then
    if(obj->in_current.loop){

        if(!obj->in_previous.loop){
            obj->playback_tick = obj->buffer.tick[0];
            obj->playback_index = 0;
        } else if(obj->playback_tick == obj->buffer.tick[obj->playback_index]){

        }

            // if obj->playback_index >= obj->buffer.index, we loop

        obj->playback_tick++;
    }

    // end-of-function stuff
    obj->in_previous = obj->in_current;

    obj->tick++;

    obj->busy = false;
}

void*
midimock_new(){
    t_midimock *x = (t_midimock *)pd_new(midimock_class);
   
    //  allocate data you need?
    inlet_new(&x->obj, &x->obj.ob_pd, 0, 0);
    floatinlet_new(&x->obj, &x->in_current.listen);
    floatinlet_new(&x->obj, &x->in_current.loop);
    floatinlet_new(&x->obj, &x->in_current.note);
    floatinlet_new(&x->obj, &x->in_current.vel);

    // MIDI_Note
    x->note_out = outlet_new(&x->obj, &s_float);
    // MIDI_Vel
    x->vel_out = outlet_new(&x->obj, &s_float);
    // Look_OK
    x->loop_ok_out = outlet_new(&x->obj, &s_float);
}

void
midimock_startup(){
    midimock_class = class_new(
        gensym("midimock"),
        (t_newmethod)midimock_new,
        0, // no destructor
        sizeof(t_midimock),
        CLASS_DEFAULT,
        0);

    class_addbang(midimock_class, midimock_bang);
}
