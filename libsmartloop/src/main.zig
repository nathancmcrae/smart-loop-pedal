const std = @import("std");

const mecha = @import("mecha/mecha.zig");

const os = std.os;
const Allocator = std.mem.Allocator;

const test_file = @embedFile("cycle-test_2020-04-15.mid.txt");

// test "nothing to see here" {
//     try readNoteFile(std.testing.allocator, test_file);
// }

/// Each line is a note on/off midi event
/// Line format: <note-type>\t<note>\t<note-time>\t<note-velocity>
///
/// note-time: 
// const noteFileParser = mecha.many(noteLine, .{.collect = true, .separator = mecha.utf8.char('\n')});
// const noteLine = mecha.oneOf(.{noteOnLine, noteOffLine});
// const noteOnLine = mecha.combine( . {
//     mecha.string("note_on"),
//     tab,
//     mecha.int(u32, 10),
//     tab,
//     mecha.int(u32, 10),
//     tab,
//     mecha.int(u32, 10),
// });
// const noteOffLine = mecha.combine( . {
//     mecha.string("note_off"),
//     tab,
//     mecha.int(u32, 10),
//     tab,
//     mecha.int(u32, 10),
//     tab,
//     mecha.int(u32, 10),

// });
// const tab = mecha.utf8.char('\t');

// pub fn readNoteFile(alloc: *Allocator, content: []const u8) !void {

//     // const a = (try noteFileParser(alloc, content));

//     // std.debug.warn("parsed content: {}\n", .{a.value});
//     // std.debug.warn("unparsed content: {}\n", .{a.rest});

//     // for(a.value) |line, i| {
//     //     std.debug.warn("line {}: {}\n", .{i, line});
//     // }
// }
 
pub fn main() !void {
    const notes = (try parseNoteFile(std.testing.allocator, test_file));
    defer std.testing.allocator.free(notes);
    std.debug.warn("test", .{});

    var note_ons = std.ArrayList(u32).init(std.testing.allocator);
    defer note_ons.deinit();

    for(notes) |note| {
        try note_ons.append(note.note_time);
    }

    var overlaps = try get_sequence_self_overlaps(std.testing.allocator, note_ons.items);
}

fn glbi_rec(list: []const u32, value: u32, ilow: u32, ihigh: u32) u32 {
    const length: u32 = @intCast(u32, list.len);
    
    std.debug.assert(0 <= ilow and ilow < length);
    std.debug.assert(0 < ihigh and ihigh <= length);

    std.debug.assert(value >= list[ilow]);
    std.debug.assert(value < list[ihigh - 1]);

    if(ilow == ihigh - 2){
        if(value == list[ilow + 1]){
            return ilow + 1;
        } else {
            return ilow;
        }
    }

    const i: u32 = (ilow + ihigh) / 2;
    std.debug.assert(i >= ilow);
    std.debug.assert(i < ihigh);

    if(value >= list[i]){
        return glbi_rec(list, value, i, ihigh);
    } else {
        return glbi_rec(list, value, ilow, i + 1);
    }
}

test "glbi empty" {
    // std.testing.expect(glbi([_]u32))
}

/// Given a list of values, and a target value, return the index of the greatest lower bound
/// of 'value' in 'list'.
/// error if value is less than all elements of the list.
pub fn glbi(list: []const u32, value: u32) ?u32 {
    const length = @intCast(u32, list.len); 
    
    const ilow = 0;
    const ihigh = length;

    if(value < list[ilow]) {
        return null;
    }
    if(value >= list[list.len - 1]){
        return length - 1;
    }

    return glbi_rec(list, value, ilow, ihigh);
}

pub fn windowFunction(v: u32, w: u32, WINDOW_LEN: u32) u64 {
    var diff: u32 = 0;
    if(v > w) {
        diff = v - w;
    } else {
        diff = w - v;
    }
    return std.math.max(0, 1 - 2 * diff / WINDOW_LEN);
}

// For each point in the shifted label sequence, get all points in the 
// original sequence within the window. Then take the sum of the 
// objective function between the shifted point and all the original 
// points in its window that have the same label
//
//   *  *     * *    * **       Original sequence
//      +     + +               Points in window
//    |     V     |             Window for shifted point
//       *  *     * *    * **   Shifted sequence
pub fn labelledSeqProduct(x: []u32, l: []u32, shift: u32, WINDOW_LEN: u32) u64 {
    std.debug.assert(x.len == l.len);
    std.debug.assert(x.len <= std.math.maxInt(u32));

    const length: u32 = @intCast(u32, x.len);
    var product: u64 = 0;

    var i: usize = 0;
    while(i < x.len) : ( i += 1 ) {
        const v = x[i] + shift;

        var window_start: usize = 0; 
        if(glbi(x, v - WINDOW_LEN / 2)) |start| {
            window_start = start + 1;
        } 
        window_start = std.math.min(std.math.max(0, window_start), length - 1);

        std.debug.assert(window_start == length - 1 or x[window_start] >= v - WINDOW_LEN/2);
        std.debug.assert(window_start == 0 or x[window_start - 1] <= v - WINDOW_LEN/2);

        var window_end: usize = 0;
        if(glbi(x, v + WINDOW_LEN/2)) |end| {
            window_end = end + 1;
        } 
        window_end = std.math.min(x.len - 1, window_end);

        std.debug.assert(window_end == 0 or x[window_end - 1] <= v + WINDOW_LEN/2);
        std.debug.assert(window_end == x.len - 1 or x[window_end] > v + WINDOW_LEN/2);

        var point_product: u64 = 0;
        var j: usize = window_start;
        while(j < window_end) : (j += 1) {
            if(j == i or l[j] != l[i]) continue;

            std.debug.assert(windowFunction(v, x[j], WINDOW_LEN) >= 0);
            point_product += windowFunction(v, x[j], WINDOW_LEN);
        }

        product += point_product;
    }
    return product;
}

test "empty labelled sequence product" {
    const empty: []u32 = try std.testing.allocator.alloc(u32, 0);
    const result = labelledSeqProduct(empty, empty, 0, 0);
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
            if(!(original[i+1] >= original[i])){
                std.debug.warn("i: {}, i+1: {}", .{original[i], original[i+1]});
            }
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
    const length: u32 = @intCast(u32, original.len);
    var next_i: u32 = length;

    while(n[0] < original.len){
        const k = @intCast(u32, try min_index(d));
        const shift = d[k];

        std.debug.assert(shift >= 0);
        total_shift += shift;
        try shifts.append(total_shift);

        // Now that we know what the shift is, update n and d to reflect the new shifted sequence.
        
        if(n[k] >= original.len - 1){
            d[k] = std.math.maxInt(u32);
            n[k] = length;
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
                    n[i] = length;
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


pub const NoteType = enum {
    note_on,
    note_off,
};

pub const NoteEvent = struct {
    note_type: NoteType,
    note: u32,
    note_time: u32,
    note_velocity: u32,
};

pub fn strCompare(a:[]const u8, b:[]const u8) bool {
    if(a.len != b.len) return false;
    for(a) |c, i| {
        if(c != b[i]){
            return false;
        }
    }
    return true;
}

pub fn parseNoteLine(line_contents: []const u8) !NoteEvent {
    var note: NoteEvent = NoteEvent{
        .note_type = NoteType.note_on,
        .note = 0,
        .note_time = 0,
        .note_velocity = 0,
    };
    var field: u8 = 0;
    var field_start: usize = 0;

    for(line_contents) |char, i| {
        if(char == '\t'){
            const field_value = line_contents[field_start..i];
            if(field == 0){
                if(strCompare(field_value, "note_on")){
                    note.note_type = NoteType.note_on;
                } else if(strCompare(field_value, "note_off")) {
                    note.note_type = NoteType.note_off;
                } else {
                    std.debug.warn("{}, {}, {}\n", .{field_value, i, field_start});
                    std.debug.warn("{}, {}\n", .{char, line_contents[i]});

                    return error.ParseError;

                }
            } else if(field == 1) {
                note.note = try std.fmt.parseUnsigned(u32, field_value, 10);
            } else if(field == 2) {
                note.note_time = try std.fmt.parseUnsigned(u32, field_value, 10);
            } else if(field == 3) {
                note.note_velocity = try std.fmt.parseUnsigned(u32, field_value, 10);
            } else {
                return error.ParseError;
            }

            field_start = i + 1;
            field += 1;
        }
    }

    std.debug.warn("({},{},{},{})", note);

    return note;
}

pub fn parseNoteFile(alloc: *Allocator, contents: []const u8) ![]NoteEvent {
    var notes: std.ArrayList(NoteEvent) = std.ArrayList(NoteEvent).init(alloc);
    defer notes.deinit();
    
    var line_start: usize = 0;
    for (contents) |char, i| {
        if(char == '\n') {
            // std.debug.print("{}", .{contents[line_start..i]});
            var line = try parseNoteLine(contents[line_start..i]);
            try notes.append(line);
            line_start = i + 1;
        }
    }

    var notes_list = try alloc.alloc(NoteEvent, notes.items.len);
    std.mem.copy(NoteEvent, notes_list, notes.items);

    return notes_list;
}


test "empty sequence means no shifts" {
    // TODO: calculate note shifts from file
    const notes = (try parseNoteFile(std.testing.allocator, test_file));

    var note_ons = std.ArrayList(u32).init(std.testing.allocator);
    defer note_ons.deinit();

    for(notes) |note| {
        try note_ons.append(note.note);
    }

    var overlaps = try get_sequence_self_overlaps(std.testing.allocator, note_ons.items);

    // std.debug.warn("parsed content: {}\n", .{a.value});
    // std.debug.warn("unparsed content: {}\n", .{a.rest});

    // var original: []u32;
    // for(file.value) |line, i| {
    //     // if(@TypeOf(line) == @TypeOf(noteOnLine)){
    //         std.debug.warn("line {}: {}\n", .{i, line});
    //     // }
    // }


    const seq1: []u32 = try std.testing.allocator.alloc(u32, 0);
    if(get_sequence_self_overlaps(std.testing.allocator, seq1)) |value| {
        std.testing.expect(false);
    } else |err| {
        std.testing.expect(err == error.EmptySequence);
    }

    const seq2: []const u32 = &[_]u32 {0, 1, 2, 3};
    const result = get_sequence_self_overlaps(std.testing.allocator, seq2);
}
