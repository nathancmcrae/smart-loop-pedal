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
    try file.writeAll("note-type\tnote\tnote-time\tnote-velocity\n");
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
    if (obj.start_time_ms == 0){
        obj.start_time_ms = @intCast(u64, std.time.milliTimestamp());
    }
    const current_time = @intCast(u64, std.time.milliTimestamp()) - obj.start_time_ms;

    if (obj.in_current.listen != 0) {
        if (obj.in_previous.listen == 0) {
            obj.buffer.index = 0;

            // reset note_on buffer
            obj.note_on_buffer.index = 0;

            obj.playback_period_ms = 0;
        } else if (!(obj.in_current.note == obj.in_previous.note and
            obj.in_current.velocity == obj.in_previous.velocity))
        {
            assert(obj.buffer.index < mock.BUFFER_LEN);

            const index: usize = obj.buffer.index;

            obj.buffer.note[index] = obj.in_current.note;
            obj.buffer.velocity[index] = obj.in_current.velocity;
            obj.buffer.time[index] = current_time;

            obj.buffer.index += 1;

            // store only note-ons in a separate buffer so we can pass them to the periodicity
            // calculations
            if (obj.in_current.velocity != 0) {
                const nindex = obj.note_on_buffer.index;
                obj.note_on_buffer.note[nindex] = obj.in_current.note;
                obj.note_on_buffer.velocity[nindex] = obj.in_current.velocity;
                obj.note_on_buffer.time[nindex] = current_time;

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
            note_ons[i] =  @truncate(u32, obj.note_on_buffer.time[i]);
            // std.debug.print("note: {}, note_on: {}, time: {}, velocity: {}\n", .{ notes[i], note_ons[i], obj.note_on_buffer.time[i], obj.note_on_buffer.velocity[i] });
        }

        if(obj.note_on_buffer.index > 0) {
            // Write a file with this note sequence

            var all_notes: [mock.BUFFER_LEN]u32 = undefined;
            var all_note_ons: [mock.BUFFER_LEN]u32 = undefined;

            var j: usize = 0;
            while(j < obj.buffer.index) : (j += 1) {
                all_notes[j] = @floatToInt(u32, obj.buffer.note[j]);
                all_note_ons[j] =  @truncate(u32, obj.buffer.time[j]);
            }
            
            if(std.fmt.allocPrint(std.heap.c_allocator, "recordings/{}.txt", .{ std.time.timestamp() }) ) |filename|{
                const write_err = writeNoteSequence(std.heap.c_allocator,
                                                    all_notes[0..obj.buffer.index],
                                                    all_note_ons[0..obj.buffer.index],
                                                    obj.buffer.velocity[0..obj.buffer.index],
                                                    filename);
                if(write_err) |_| {} else |err| {
                    mock.post("error writing recording file");
                }
            } else |err| {
                mock.post("error generating filename");
            }
        }

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
            return;
        }

        var time2 = std.time.nanoTimestamp();

        std.debug.print("time2-time1: {} ns\n", .{time2 - time1});

        // start looping
        // obj.playback_tick = @mod((obj.tick - obj.buffer.tick[0]) , (obj.playback_period_ms / @floatToInt(u32, obj.in_current.tick_ms))) + obj.buffer.tick[0] - 23;
        // var ticks_err = std.heap.c_allocator.alloc(u32, obj.note_on_buffer.index);
        // if (ticks_err) |ticks| {
        //     defer std.heap.c_allocator.free(ticks);
        //     var j: usize = 0;
        //     while(j < obj.note_on_buffer.index) : (j += 1){
        //         ticks[j] = @intCast(u32, obj.buffer.tick[j]);
        //     }
        //     obj.playback_index = sloop.glbi(ticks, @intCast(u32, obj.playback_tick)) orelse 0;
        //     std.debug.print("playback_tick: {}\nplayback_index: {}\ntick[index]: {}\n", .{obj.playback_tick, obj.playback_index, obj.buffer.tick[obj.playback_index]});
        // } else |err| {}

        
        obj.playback_start_time_ms = obj.buffer.time[0];
        obj.playback_iteration = (current_time - obj.playback_start_time_ms) / obj.playback_period_ms;
        const playback_time = @mod(current_time - obj.playback_start_time_ms, obj.playback_period_ms) + obj.buffer.time[0];
        const times_err = std.heap.c_allocator.alloc(u32, obj.buffer.index);
        if (times_err) |times| {
            defer std.heap.c_allocator.free(times);

            var j: usize = 0;
            while (j < obj.buffer.index) : (j += 1) {
                times[j] = @intCast(u32, obj.buffer.time[j]);
            }
            obj.playback_index = sloop.glbi(times, @intCast(u32, playback_time)) orelse 0;
            if(obj.buffer.time[obj.playback_index] < playback_time) {
                    obj.playback_index += 1;
            }
        } else |err| {}

    }

    // if (obj.in_current.loop != 0) {
    //     if (obj.in_previous.loop == 0) {
    //         obj.playback_index = 0;
    //         obj.playback_start_time_ms = current_time;
    //     } else {
    if(obj.in_current.listen == 0 and obj.playback_period_ms != 0) {
        // std.debug.print("playback time: {}, next note: {}\n", .{@mod(current_time - obj.playback_start_time_ms, obj.playback_period_ms) + obj.buffer.time[0], obj.buffer.time[obj.playback_index]});
        const playback_time = @mod(current_time - obj.playback_start_time_ms, obj.playback_period_ms) + obj.buffer.time[0];
        const next_note_time = obj.buffer.time[obj.playback_index];

        if(playback_time > next_note_time and playback_time - next_note_time > 100){
            // TODO: if there is excessive delay, then reset the playback index?
            // we just want to catch up and don't want to play a ton of notes
            mock.post("Excessive delay during playback");
        }

        if (playback_time >= next_note_time) {
            mock.outlet_float(obj.velocity_out, obj.buffer.velocity[obj.playback_index]);
            mock.outlet_float(obj.note_out, obj.buffer.note[obj.playback_index]);

            obj.playback_index = obj.playback_index + 1;

            // std.debug.print("next tick: {}\n", .{obj.buffer.tick[obj.playback_index]});
        }
        const current_iteration = (current_time + 10 - obj.playback_start_time_ms) / obj.playback_period_ms;
        if(current_iteration > obj.playback_iteration){
            std.debug.print("resetting playback; time: {}\n", .{ current_time });
            obj.playback_index = 0;
            obj.playback_iteration = current_iteration;
        }
    }

    obj.in_previous = obj.in_current;
    obj.previous_bang_time = current_time;
}

export fn midimock_float(obj: *mock.t_midimock, value: f32) void {
    if (obj.in_current.loop == 0) {
        obj.in_current.note = value;
        midimock_bang(obj);
    }
}
