#include <m_pd.h>

static t_class *midimock_class;

typedef struct _midimock {
    t_object obj;
    //  need something to hold the midi data
    t_float listen;
    t_float loop;
    t_float note;
    t_float vel;
    t_outlet *note_out, *vel_out, *loop_ok_out;
    bool busy;
} t_midimock;

void
midimock_bang(t_midimock* obj){
    // do what you want with the bang
    // This will be trigered every N milliseconds
    //   Will it be re-entrant if I just have a 'busy' flag in t_midimock that
    //   I set when I start this function and clear when I finish it?
}

// I don't think we will receive floats from the active
void midimock_float(t_midimock* obj){
}

void*
midimock_new(){
    t_midimock *x = (t_midimock *)pd_new(midimock_class);
   
    //  allocate data you need?
    inlet_new(&x->obj, &x->obj.ob_pd, 0, 0);
    floatinlet_new(&x->obj, &x->listen);
    floatinlet_new(&x->obj, &x->loop);
    floatinlet_new(&x->obj, &x->note);
    floatinlet_new(&x->obj, &x->vel);

    // MIDI_Note
    x->note_out = outlet_new(&x->obj, &s_float);
    // MIDI_Vel
    x->vel_out = outlet_new(&x->obj, &s_float);
    // Look_OK
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

    class_addfloat(midimock_class, midimock_float);
    class_addbang(midimock_class, midimock_bang);
}
