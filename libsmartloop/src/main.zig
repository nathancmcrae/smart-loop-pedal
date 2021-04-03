const std = @import("std");

const mecha = @import("mecha/mecha.zig");

const os = std.os;
const Allocator = std.mem.Allocator;

const contents = @embedFile("cycle-test_2020-04-15.mid.txt");

test "nothing to see here" {
    try readNoteFile(std.testing.allocator, contents);
}

/// Each line is a note on/off midi event
/// Line format: <note-type>\t<note>\t<note-time>\t<note-velocity>
///
/// note-time: 
const noteFileParser = mecha.many(noteLine, .{.collect = false, .separator = mecha.utf8.char('\n')});
const noteLine = mecha.oneOf(.{noteOnLine, noteOffLine});
const noteOnLine = mecha.combine( . {
    mecha.string("note_on"),
    tab,
    mecha.int(u32, 10),
    tab,
    mecha.int(u32, 10),
    tab,
    mecha.int(u32, 10),
});
const noteOffLine = mecha.combine( . {
    mecha.string("note_off"),
    tab,
    mecha.int(u32, 10),
    tab,
    mecha.int(u32, 10),
    tab,
    mecha.int(u32, 10),

});
const tab = mecha.utf8.char('\t');

pub fn readNoteFile(alloc: *Allocator, content: []const u8) !void {

    const a = (try noteFileParser(alloc, content));

    std.debug.warn("parsed content: {}\n", .{a.value});
    std.debug.warn("unparsed content: {}\n", .{a.rest});

    // for(a) |line, i| {
    //     std.debug.warn("line {}: {}\n", .{i, line});
    // }
}
 
pub fn main() !void {
    try readNoteFile(std.testing.allocator, contents);
    std.debug.warn("am run\n", .{});

}

fn glbi_rec(list: []const u32, value: u32, ilow: u32, ihigh: u32) u32 {
    std.debug.assert(0 <= ilow and ilow < list.len);
    std.debug.assert(0 < ihigh and ihigh <= list.len);

    std.debug.assert(v >= list[ilow]);
    std.debug.assert(v < list[ihigh - 1]);

    if(ilow == ihigh - 2){
        if(v == list[ilow + 1]){
            return ilow + 1;
        } else {
            return ilow;
        }
    }

    const i: u32 = std.math.floor((ilow + ihigh) / 2);
    std.debug.assert(i >= ilow);
    std.debug.assert(i < ihigh);

    if(v >= list[i]){
        return glbi_rec(list, v, i, ihigh);
    } else {
        return glbi_rec(list, v, ilow, i + 1);
    }
}

test "glbi empty" {
    // std.testing.expect(glbi([_]u32))
}

/// Given a list of values, and a target value, return the index of the greatest lower bound
/// of 'value' in 'list'.
/// Return -1 if value is less than all elements of the list.
pub fn glbi(list: []const u32, value: u32) u32 {
    ilow = 0;
    ihigh = list.length;

    if(v < list[ilow]) {
        return -1;
    }
    if(v >= list[list.len - 1]){
        return list.len - 1;
    }

    return glbi_rec(list, value, ilow, ihigh);
}

/// Return the index of the minimum element of the list.
/// If multiple elements are minimum, the first one is returned.
/// If the list is empty, an error.EmptySequence is returned.
fn min_index(list: []u32) !usize {
    if(list.len == 0){
        return error.EmptySequence;
    }

    var current_min: usize = 0;
    var min_value = list[current_min];
    for(list) |value, i| {
        if(value < min_value){
            current_min = i;
            min_value = value;
        }
    }

    std.debug.assert(current_min < list.len);
    return current_min;
} 

pub const self_overlap_results = struct {
    s: []u32,
    i: []u32,
};

/// Given an impulse sequence, return a list of all shifts that would cause a shifted version
/// of the sequence to have at least one overlap with the original sequence.
pub fn get_sequence_self_overlaps(alloc: *Allocator, original: []const u32) !self_overlap_results {
    if(original.len == 0){
        return error.EmptySequence;
    }
    
    // n[i] is the index of the impulse in the original sequence nearest 'in front of' the ith
    // impulse of the shifted sequence. i.e. for the ith impulse of the shifted sequence, which
    // impulse of the original sequence it will encounter next as the shifted sequence is shifted
    // more.
    var n = try alloc.alloc(u32, original.len);
    defer alloc.free(n);

    // d[i] is the distance from the ith shifted impulse to the next original impulse
    var d = try alloc.alloc(u32, original.len - 1);
    defer alloc.free(d);

    // Initialize d
    for (original) |value, i| {
        if(i < d.len) {
            d[i] = original[i + 1] - original[i];
        }
    }

    // How much the shifted sequence is shifted from the original
    // Note, we don't actually store the shifted sequence, but conceptually:
    // shifted[i] = original[i] + total_shift
    var total_shift: u32 = 0;

    var shifts = std.ArrayList(u32).init(alloc);
    try shifts.ensureCapacity(2 * original.len);
    defer shifts.deinit();

    var next_is = std.ArrayList(u32).init(alloc);
    try next_is.ensureCapacity(2 * original.len);
    defer next_is.deinit();

    // If you use more than 32 bits for your impulse sequence you deserve what you get.
    if(original.len > std.math.maxInt(u32)){
        return error.SequenceTooLarge;
    }
    var next_i: u32 = @intCast(u32, original.len);

    while(n[0] < original.len){
        const k = @intCast(u32, try min_index(d));
        const shift = d[k];

        std.debug.assert(shift >= 0);
        total_shift += shift;
        try shifts.append(total_shift);

        // Now that we know what the shift is, update n and d to reflect the new shifted sequence.
        
        if(n[k] >= original.len - 1){
            d[k] = std.math.maxInt(u32);
            n[k] = @intCast(u32, original.len);
            next_i = k;
        } else {
            d[k] = original[n[k] + 1] - original[n[k]];
            n[k] += 1;
        }

        var i: u32 = 0;
        while(i < d.len) : (i += 1) {
            if(i == k or n[i] > original.len - 1) {
                continue;
            }

            d[i] -= shift;
            std.debug.assert(d[i] >= 0);

            // If impulse i has same distance to next impulse as impulse k does, then we don't want
            // to record a redundant shift value of the same amount. So increment the 'next' impulse
            // for impulse i
            if(d[i] == 0) {
                if(n[i] >= original.len - 1){
                    d[i] = std.math.maxInt(u32);
                    n[i] = @intCast(u32, original.len);
                    next_i = i;
                } else {
                    d[i] = original[n[i] + 1] - original[n[i]];
                    n[i] = n[i] + 1;
                }
            }

            try next_is.append(next_i);
        }
    }

    const result: self_overlap_results = . {
        .s = shifts.items,
        .i = next_is.items,
    };

    return result;
}

test "empty sequence means no shifts" {
    const seq1: []u32 = try std.testing.allocator.alloc(u32, 0);
    if(get_sequence_self_overlaps(std.testing.allocator, seq1)) |value| {
        std.testing.expect(false);
    } else |err| {
        std.testing.expect(err == error.EmptySequence);
    }

    const seq2: []const u32 = &[_]u32 {0, 1, 2, 3};
    const result = get_sequence_self_overlaps(std.testing.allocator, seq2);
}
