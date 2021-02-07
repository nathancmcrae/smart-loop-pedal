// NathanMcRae.name
// 2021-01-06

const std = @import("std");
const mock = @cImport(@cInclude("midimock.h"));

const assert = std.debug.assert;

export fn bar(b: c_int) bool {
    return b >= 5;
}

export fn midimock_bang(obj: *mock.t_midimock) void {
    if(obj.busy) return;
    obj.busy = true;

    if(obj.in_current.listen != 0){
        if(obj.in_previous.listen == 0){
            obj.buffer.index = 0;

            obj.buffer.note[0] = -1;
            obj.buffer.velocity[0] = -1;
            obj.buffer.tick[0] = obj.tick;
        } else if (!(obj.in_current.note == obj.in_previous.note and
                         obj.in_current.velocity == obj.in_previous.velocity)){
            assert(obj.buffer.index < mock.BUFFER_LEN);

            const index: usize = obj.buffer.index;

            obj.buffer.note[index] = obj.in_current.note;
            obj.buffer.velocity[index] = obj.in_current.velocity;
            obj.buffer.tick[index] = obj.tick;

            obj.buffer.index = obj.buffer.index + 1;
        }
    } else if(obj.in_previous.listen != 0){
            // mock.post(std.fmt.format("Recorded {} notes", obj.buffer.index));
    }


    obj.tick = obj.tick + 1;
    obj.busy = false;
}
