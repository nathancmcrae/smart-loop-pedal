#include "midimock.h"

static t_class *midimock_class;

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
    } else if(obj->in_previous.listen) {

        post("Recorded %d notes", obj->buffer.index);
        for(int i = 0; i < obj->buffer.index; i++){
            post("%d: %f, %f, %d",
                 i,
                 obj->buffer.note[i],
                 obj->buffer.velocity[i],
                 obj->buffer.tick[i]);
        }
    }

    // If we're looping, then
    if(obj->in_current.loop){

        if(!obj->in_previous.loop){
            obj->playback_tick = obj->buffer.tick[0] - 1;
            obj->playback_index = 0;
        } else if(obj->playback_tick == obj->buffer.tick[obj->playback_index]){
            // play this note
            post("Play note %d: %f, %f, %d",
                 obj->playback_index,
                 obj->buffer.note[obj->playback_index],
                 obj->buffer.velocity[obj->playback_index],
                 obj->buffer.tick[obj->playback_index]);
            outlet_float(obj->velocity_out, obj->buffer.velocity[obj->playback_index]);
            outlet_float(obj->note_out, obj->buffer.note[obj->playback_index]);

            obj->playback_index++;

            post("obj->playback_index: %d", obj->playback_index);
            post("obj->buffer.index: %d", obj->buffer.index);

            // Loop
            if(obj->playback_index >= obj->buffer.index){
                post("Trying to loop");
                obj->playback_tick = obj->buffer.tick[0] - 1;
                obj->playback_index = 0;
            }
        }

        obj->playback_tick++;
    }

    // test zig integration
    if(bar(obj->tick % 6)){
        post("ziggy time");
    }

    // end-of-function stuff
    obj->in_previous = obj->in_current;

    obj->tick++;

    obj->busy = false;
}

void*
midimock_new(){
    t_midimock *x = (t_midimock *)pd_new(midimock_class);

    // Just initialize everything so that errors from bad indexing are consistent
    for(int i = 0; i < BUFFER_LEN; i++){
        x->buffer.note[i] = 0;
        x->buffer.velocity[i] = 0;
        x->buffer.tick[i] = 0;
    }
    x->buffer.index = 0;

    x->busy = false;
    x->tick = 0;
    x->playback_tick = 0;
    x->playback_index = 0;

    floatinlet_new(&x->obj, &x->in_current.listen);
    floatinlet_new(&x->obj, &x->in_current.loop);
    floatinlet_new(&x->obj, &x->in_current.note);
    floatinlet_new(&x->obj, &x->in_current.velocity);

    x->note_out = outlet_new(&x->obj, &s_float);
    x->velocity_out = outlet_new(&x->obj, &s_float);
    x->loop_ok_out = outlet_new(&x->obj, &s_float);

    return (void *)x;
}

void
midimock_setup(){
    midimock_class = class_new(
        gensym("midimock"),
        (t_newmethod)midimock_new,
        0, // no destructor
        sizeof(t_midimock),
        CLASS_DEFAULT,
        0);

    class_addbang(midimock_class, midimock_bang);
}
