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
        var message_buf: [100]u8 = undefined;
        const message_slice = message_buf[0..];

        var message = std.fmt.bufPrint(message_slice, "Recorded {} notes", .{ obj.buffer.index });
        
        if(message) |actual_message| {
            mock.post(actual_message.ptr);
        } else |err| {
            mock.post("Recorded some notes");
        }
    }

    if(obj.in_current.loop != 0){
        if(obj.in_previous.loop == 0) {
            obj.playback_tick = obj.buffer.tick[0] - 1;
            obj.playback_index = 0;
        } else if(obj.playback_tick == obj.buffer.tick[obj.playback_index]){
            mock.outlet_float(obj.velocity_out, obj.buffer.velocity[obj.playback_index]);
            mock.outlet_float(obj.note_out, obj.buffer.note[obj.playback_index]);

            obj.playback_index = obj.playback_index + 1;

            if(obj.playback_index >= obj.buffer.index){
                obj.playback_tick = obj.buffer.tick[0] - 1;
                obj.playback_index = 0;
            }
        }

        obj.playback_tick = obj.playback_tick + 1;
    }

    obj.in_previous = obj.in_current;

    obj.tick = obj.tick + 1;
    obj.busy = false;
}
