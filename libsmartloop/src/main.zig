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

pub const self_overlap_results = struct {
    s: []u32,
    i: []u32,
};

/// Given an impulse sequence, return a list of all shifts that would cause a shifted version
/// of the sequence to have at least one overlap with the original sequence.
pub fn get_sequence_self_overlaps(alloc: *Allocator, original: [] u32) !self_overlap_results {
    if(original.len == 0){
        return error.EmptySequence;
    }
    
    // n[i] is the index of the impulse in the original sequence nearest 'in front of' the ith
    // impulse of the shifted sequence. i.e. for the ith impulse of the shifted sequence, which
    // impulse of the original sequence it will encounter next as the shifted sequence is shifted more.
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

    var next_i = original.len;

    while(n[0] < original.len){
        
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

    // const seq2 = []u32 {0};
    // const result = get_sequence_self_overlaps(std.testing.allocator, seq2);
}
