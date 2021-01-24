// NathanMcRae.name
// 2021-01-06

const std = @import("std");
const mock = @cImport(@cInclude("midimock.h"));

export fn bar(b: c_int) bool {
    return b >= 5;
}

export fn midimock_bang(obj: *mock.t_midimock) void {
    if(obj.busy) return;
    obj.busy = true;

    if(@mod(obj.tick, 6) >= 5){
        mock.post("ziggy time 2.0");
    }

    obj.tick = obj.tick + 1;
    obj.busy = false;
}
