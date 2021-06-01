// NathanMcRae.name
// 2021-01-06

const std = @import("std");
const sloop = @import("../libsmartloop/src/main.zig");
const mock = @cImport(@cInclude("midimock.h"));

const assert = std.debug.assert;

export fn bar(b: c_int) bool {
    return b >= 5;
}

fn writeNoteSequence(alloc: *std.mem.Allocator, notes: []u32, note_times: []u32, note_velocities: []f32, file_path: []u8) !void {
    const file = try std.fs.cwd().createFile(
        file_path,
        .{},
    );
    defer file.close();

    const length = std.math.max(notes.len, std.math.max(note_times.len, note_velocities.len));
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const note_type = if (note_velocities[i] == 0) "note_off" else "note_on";
        const line = try std.fmt.allocPrint(alloc, "{}\t{}\t{}\t{}\n", .{
            note_type,
            notes[i],
            note_times[i],
            @floatToInt(u32, note_velocities[i]),
        });
        try file.writeAll(line);
    }
}

export fn midimock_bang(obj: *mock.t_midimock) void {
    if (obj.busy) return;
    obj.busy = true;

    if (obj.in_current.listen != 0) {
        if (obj.in_previous.listen == 0) {
            obj.buffer.index = 0;

            obj.buffer.note[0] = -1;
            obj.buffer.velocity[0] = -1;
            obj.buffer.tick[0] = obj.tick;

            // reset note_on buffer
            obj.note_on_buffer.index = 0;

            obj.note_on_buffer.note[0] = -1;
            obj.note_on_buffer.velocity[0] = -1;
            obj.note_on_buffer.tick[0] = obj.tick;

            obj.playback_period_ms = 0;
        } else if (!(obj.in_current.note == obj.in_previous.note and
            obj.in_current.velocity == obj.in_previous.velocity))
        {
            assert(obj.buffer.index < mock.BUFFER_LEN);

            const index: usize = obj.buffer.index;

            obj.buffer.note[index] = obj.in_current.note;
            obj.buffer.velocity[index] = obj.in_current.velocity;
            obj.buffer.tick[index] = obj.tick;

            obj.buffer.index = obj.buffer.index + 1;

            // store only note-ons in a separate buffer so we can pass them to the periodicity
            // calculations
            if (obj.in_current.velocity != 0) {
                const nindex = obj.note_on_buffer.index;
                obj.note_on_buffer.note[nindex] = obj.in_current.note;
                obj.note_on_buffer.velocity[nindex] = obj.in_current.velocity;
                obj.note_on_buffer.tick[nindex] = obj.tick;

                obj.note_on_buffer.index = obj.note_on_buffer.index + 1;
            }
        }
    } else if (obj.in_previous.listen != 0) {
        var message_buf: [100]u8 = undefined;
        const message_slice = message_buf[0..];

        var message = std.fmt.bufPrint(message_slice, "Recorded {} notes\x00", .{obj.buffer.index});

        if (message) |actual_message| {
            mock.post(actual_message.ptr);
        } else |err| {
            mock.post("Recorded some notes");
        }

        var time1 = std.time.nanoTimestamp();

        // try to calculate loop periodicity
        var notes: [mock.BUFFER_LEN]u32 = undefined;
        var note_ons: [mock.BUFFER_LEN]u32 = undefined;
        var i: usize = 0;
        // std.debug.print("obj.in_current.tick_ms: {}", .{obj.in_current.tick_ms});
        while (i < obj.note_on_buffer.index) : (i += 1) {
            if (obj.note_on_buffer.velocity[i] == 0) continue;
            notes[i] = @floatToInt(u32, obj.note_on_buffer.note[i]);
            note_ons[i] = @floatToInt(u32, obj.in_current.tick_ms) * @truncate(u32, obj.note_on_buffer.tick[i]);
            // std.debug.print("note: {}, note_on: {}, obj.buffer.tick: {}, velocity: {}\n", .{ notes[i], note_ons[i], obj.note_on_buffer.tick[i], obj.note_on_buffer.velocity[i] });
        }

        var periodicity_err1 = sloop.getPeriodicity(std.heap.c_allocator, note_ons[0..obj.note_on_buffer.index], notes[0..obj.note_on_buffer.index]);
        if (periodicity_err1) |periodicity| {
            var message1 = std.fmt.bufPrint(message_slice, "first iteration periodicity power: {}, periodicity: {}", periodicity);
            if (message1) |actual_message| {
                mock.post(actual_message.ptr);
            } else |err| {}

            obj.playback_period_ms = periodicity.periodicity;
        } else |err| {}

        var overlaps_err = sloop.get_sequence_self_overlaps(std.heap.c_allocator, note_ons[0..obj.note_on_buffer.index]);
        if (overlaps_err) |overlaps| {
            defer std.heap.c_allocator.free(overlaps.shifts);
            defer std.heap.c_allocator.free(overlaps.next_is);

            var periodicity_err = sloop.getFinePeriodicity(std.heap.c_allocator, note_ons[0..obj.note_on_buffer.index], notes[0..obj.note_on_buffer.index], overlaps, 50, 100);
            if (periodicity_err) |periodicity| {
                var message1 = std.fmt.bufPrint(message_slice, "periodicity power: {}, periodicity: {}\x00", periodicity);
                if (message1) |actual_message| {
                    mock.post(actual_message.ptr);
                } else |err| {}

                obj.playback_period_ms = periodicity.periodicity;
            } else |err| {
                std.debug.print("error while getting periodicity: {}\n", .{err});
            }
        } else |err| {
            std.debug.print("error while getting overlaps: {}\n", .{err});
        }

        var time2 = std.time.nanoTimestamp();

        std.debug.print("time2-time1: {} ns\n", .{time2 - time1});
    }

    if (obj.in_current.loop != 0) {
        if (obj.in_previous.loop == 0) {
            obj.playback_tick = obj.buffer.tick[0] - 1;
            obj.playback_index = 0;
        } else {
            while (obj.playback_tick == obj.buffer.tick[obj.playback_index]) {
                mock.outlet_float(obj.velocity_out, obj.buffer.velocity[obj.playback_index]);
                mock.outlet_float(obj.note_out, obj.buffer.note[obj.playback_index]);

                obj.playback_index = obj.playback_index + 1;
                // std.debug.print("next tick: {}\n", .{obj.buffer.tick[obj.playback_index]});
            }

            obj.playback_tick = obj.playback_tick + 1;
            // std.debug.print("playback_tick: {}\n", .{obj.playback_tick});

            // if (obj.playback_index >= obj.buffer.index) {
            if ((obj.playback_tick - obj.buffer.tick[0]) * @floatToInt(u32, obj.in_current.tick_ms) >= obj.playback_period_ms) {
                std.debug.print("current time: {}\n", .{(obj.playback_tick - obj.buffer.tick[0]) * @floatToInt(u32, obj.in_current.tick_ms)});
                obj.playback_tick = obj.buffer.tick[0] - 1;
                obj.playback_index = 0;
            }
        }
    }

    obj.in_previous = obj.in_current;

    obj.tick += 1;
    obj.busy = false;
}

export fn midimock_float(obj: *mock.t_midimock, value: f32) void {
    if (obj.in_current.loop == 0) {
        obj.in_current.note = value;
        midimock_bang(obj);

        // We only want the tick to increment when we get triggered from the metronome, not when we
        // get triggered from note input. Otherwise it screws up playback
        obj.tick -= 1;
    }
}
