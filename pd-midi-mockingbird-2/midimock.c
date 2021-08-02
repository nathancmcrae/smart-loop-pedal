#include "midimock.h"

static t_class *midimock_class;

void*
midimock_new(){
    t_midimock *x = (t_midimock *)pd_new(midimock_class);

    // Just initialize everything so that errors from bad indexing are consistent
    for(int i = 0; i < BUFFER_LEN; i++){
        x->buffer.note[i] = 0;
        x->buffer.velocity[i] = 0;
        x->buffer.time[i] = 0;
    }
    x->buffer.index = 0;

    x->playback_index = 0;

    floatinlet_new(&x->obj, &x->in_current.listen);
    floatinlet_new(&x->obj, &x->in_current.loop);
    // active 'note' input
    inlet_new(&x->obj, &x->obj, &s_float, &s_float);
    floatinlet_new(&x->obj, &x->in_current.velocity);
    floatinlet_new(&x->obj, &x->in_current.control_period_ms);

    x->note_out = outlet_new(&x->obj, &s_float);
    x->velocity_out = outlet_new(&x->obj, &s_float);
    x->loop_time = outlet_new(&x->obj, &s_float);

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
    class_addfloat(midimock_class, midimock_float);
}
