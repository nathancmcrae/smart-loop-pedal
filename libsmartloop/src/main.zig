const std = @import("std");

const mecha = @import("mecha/mecha.zig");

const os = std.os;
const Allocator = std.mem.Allocator;

pub const test_file = @embedFile("cycle-test_2020-04-15.mid.txt");
const verbose: bool = false;

fn glbi_rec(list: []const u32, value: u32, ilow: u32, ihigh: u32) u32 {
    const length: u32 = @intCast(u32, list.len);

    std.debug.assert(0 <= ilow and ilow < length);
    std.debug.assert(0 < ihigh and ihigh <= length);

    std.debug.assert(value >= list[ilow]);
    std.debug.assert(value < list[ihigh - 1]);

    if (ilow == ihigh - 2) {
        if (value == list[ilow + 1]) {
            return ilow + 1;
        } else {
            return ilow;
        }
    }

    const i: u32 = (ilow + ihigh) / 2;
    std.debug.assert(i >= ilow);
    std.debug.assert(i < ihigh);

    if (value >= list[i]) {
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

    if (value < list[ilow]) {
        return null;
    }
    if (value >= list[list.len - 1]) {
        return length - 1;
    }

    return glbi_rec(list, value, ilow, ihigh);
}

pub fn windowFunction(v: u32, w: u32, WINDOW_LEN: u32) u64 {
    var diff: u32 = 0;
    if (v > w) {
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
    while (i < x.len) : (i += 1) {
        const v = x[i] + shift;

        var window_start: usize = 0;
        if (WINDOW_LEN / 2 < v) {
            if (glbi(x, v - WINDOW_LEN / 2)) |start| {
                window_start = start + 1;
            }
        }
        window_start = std.math.min(std.math.max(0, window_start), length - 1);

        // std.debug.assert(window_start == length - 1 or x[window_start] >= v - WINDOW_LEN / 2);
        // std.debug.assert(window_start == 0 or x[window_start - 1] <= v - WINDOW_LEN / 2);

        var window_end: usize = 0;
        if (glbi(x, v + WINDOW_LEN / 2)) |end| {
            window_end = end + 1;
        }
        window_end = std.math.min(x.len - 1, window_end);

        std.debug.assert(window_end == 0 or x[window_end - 1] <= v + WINDOW_LEN / 2);
        std.debug.assert(window_end == x.len - 1 or x[window_end] > v + WINDOW_LEN / 2);

        var point_product: u64 = 0;
        var j: usize = window_start;
        while (j < window_end) : (j += 1) {
            if (j == i or l[j] != l[i]) continue;

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
    if (list.len == 0) {
        return error.EmptySequence;
    }

    var current_min: usize = 0;
    var min_value = list[current_min];
    for (list) |value, i| {
        if (value < min_value) {
            current_min = i;
            min_value = value;
        }
    }

    std.debug.assert(current_min < list.len);
    return current_min;
}

/// Return the index of the maxiumum element of the list.
/// If multiple elements are maximum, the first one is returned.
/// If the list is empty, an error.EmptySequence is returned.
fn max_index(comptime t: type, list: []t) usize {
    if (list.len == 0) {
        return 0;
    }

    var current_max: usize = 0;
    var max_value = list[current_max];
    for (list) |value, i| {
        if (value < max_value) {
            current_max = i;
            max_value = value;
        }
    }

    std.debug.assert(current_max < list.len);
    return current_max;
}

pub const self_overlap_results = struct {
    // Each shift of the input sequence which will overlap one or more impulses
    shifts: []u32,
    // next_is[i] is the index of the impulse which will overlap next, after shifts[i]
    next_is: []u32,
};

/// Given an impulse sequence, return a list of all shifts that would cause a shifted version
/// of the sequence to have at least one overlap with the original sequence.
pub fn get_sequence_self_overlaps(alloc: *Allocator, original: []const u32) !self_overlap_results {
    if (original.len == 0) {
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

    // Initialize d and n
    for (original) |value, i| {
        if (verbose) std.debug.print("x[{}]: {}\n", .{ i, value });
        n[i] = @truncate(u32, i) + 1;
        if (i < d.len) {
            std.debug.assert(original[i + 1] >= original[i]);
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
    if (original.len > std.math.maxInt(u32)) {
        return error.SequenceTooLarge;
    }
    const length: u32 = @intCast(u32, original.len);
    var next_i: u32 = length;

    while (n[0] < original.len) {
        const k = @intCast(u32, try min_index(d));
        const shift = d[k];

        if (verbose) std.debug.print("n[0]: {}\nk: {}\n", .{ n[0], k });

        std.debug.assert(shift >= 0);
        total_shift += shift;
        try shifts.append(total_shift);
        if (verbose) std.debug.print("Shift: {}\n", .{total_shift});

        // Now that we know what the shift is, update n and d to reflect the new shifted sequence.

        if (n[k] >= original.len - 1) {
            d[k] = std.math.maxInt(u32);
            n[k] = length;
            next_i = k;
        } else {
            d[k] = original[n[k] + 1] - original[n[k]];
            n[k] += 1;
        }

        var i: u32 = 0;
        while (i < d.len) : (i += 1) {
            if (i == k or n[i] > original.len - 1) {
                continue;
            }

            d[i] -= shift;
            std.debug.assert(d[i] >= 0);

            // If impulse i has same distance to next impulse as impulse k does, then we don't want
            // to record a redundant shift value of the same amount. So increment the 'next' impulse
            // for impulse i
            if (d[i] == 0) {
                if (n[i] >= original.len - 1) {
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

    if (verbose) std.debug.print("done overlapping; length: {}\n", .{shifts.items.len});

    var shifts_out = try alloc.alloc(u32, shifts.items.len);
    std.mem.copy(u32, shifts_out, shifts.items);

    var next_is_out = try alloc.alloc(u32, next_is.items.len);
    std.mem.copy(u32, next_is_out, next_is.items);

    const result: self_overlap_results = .{
        .shifts = shifts_out,
        .next_is = next_is_out,
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

pub fn strCompare(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a) |c, i| {
        if (c != b[i]) {
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

    for (line_contents) |char, i| {
        if (char == '\t') {
            const field_value = line_contents[field_start..i];
            if (field == 0) {
                if (strCompare(field_value, "note_on")) {
                    note.note_type = NoteType.note_on;
                } else if (strCompare(field_value, "note_off")) {
                    note.note_type = NoteType.note_off;
                } else {
                    std.debug.warn("{}, {}, {}\n", .{ field_value, i, field_start });
                    std.debug.warn("{}, {}\n", .{ char, line_contents[i] });

                    return error.ParseError;
                }
            } else if (field == 1) {
                note.note = try std.fmt.parseUnsigned(u32, field_value, 10);
            } else if (field == 2) {
                note.note_time = try std.fmt.parseUnsigned(u32, field_value, 10);
            } else if (field == 3) {
                note.note_velocity = try std.fmt.parseUnsigned(u32, field_value, 10);
            } else {
                return error.ParseError;
            }

            field_start = i + 1;
            field += 1;
        }
    }

    // std.debug.warn("({},{},{},{})\n", note);

    return note;
}

pub fn parseNoteFile(alloc: *Allocator, contents: []const u8) ![]NoteEvent {
    var notes: std.ArrayList(NoteEvent) = std.ArrayList(NoteEvent).init(alloc);
    defer notes.deinit();

    var line_start: usize = 0;
    for (contents) |char, i| {
        if (char == '\n') {
            // std.debug.print("{}\n", .{contents[line_start..i]});
            var line = try parseNoteLine(contents[line_start..i]);
            try notes.append(line);
            line_start = i + 1;
        }
    }

    var notes_list = try alloc.alloc(NoteEvent, notes.items.len);
    std.mem.copy(NoteEvent, notes_list, notes.items);

    return notes_list;
}

test "get overlaps of test file" {
    const noteEvents = (try parseNoteFile(std.testing.allocator, test_file));
    defer std.testing.allocator.free(noteEvents);
    std.debug.warn("test\n", .{});

    var note_ons = std.ArrayList(u32).init(std.testing.allocator);
    defer note_ons.deinit();

    var notes = std.ArrayList(u32).init(std.testing.allocator);
    defer notes.deinit();

    for (noteEvents) |note| {
        if (note.note_type == NoteType.note_on) {
            try note_ons.append(note.note_time);
            try notes.append(note.note);
        }
    }

    var time1 = std.time.nanoTimestamp();

    var overlaps = try get_sequence_self_overlaps(std.testing.allocator, note_ons.items);
    // defer std.testing.allocator.free(overlaps.shifts);
    // defer std.testing.allocator.free(overlaps.next_is);

    var time2 = std.time.nanoTimestamp();

    std.debug.print("shifts: {}\n", .{overlaps.shifts.len});

    var shift_scores = std.ArrayList(u64).init(std.testing.allocator);
    defer shift_scores.deinit();

    for (overlaps.shifts) |overlap, i| {
        var score = labelledSeqProduct(note_ons.items, notes.items, overlap, 50);
        // std.debug.print("shift {}: {}, score: {}\n", .{i, overlap, score});
    }

    var time3 = std.time.nanoTimestamp();

    std.debug.print("time2-time1: {} ns\n", .{time2 - time1});
    std.debug.print("time3-time2: {} ns\n", .{time3 - time2});
}

test "empty sequence means no shifts" {
    const seq1: []u32 = try std.testing.allocator.alloc(u32, 0);
    if (get_sequence_self_overlaps(std.testing.allocator, seq1)) |value| {
        std.testing.expect(false);
    } else |err| {
        std.testing.expect(err == error.EmptySequence);
    }

    const seq2: []const u32 = &[_]u32{ 0, 1, 2, 3 };
    const result = try get_sequence_self_overlaps(std.testing.allocator, seq2);
    defer std.testing.allocator.free(result.shifts);
    defer std.testing.allocator.free(result.next_is);
}

pub const GetPeriodicityResult = struct {
    /// How periodic the input sequence is
    /// 0 means unable to establish any periodicity (incl. errors)
    periodicity_power: u64,
    /// the loop length in ms
    periodicity: u32,
};

/// Given a labelled impulse sequence, return its periodicity
///
/// x is the impulse sequence as a monotonic array of times in ms
/// l is the array of labels for each impulse in x (labels are e.g. notes in a phrase of music)
pub fn getPeriodicity(alloc: *Allocator, x: []u32, l: []u32) !GetPeriodicityResult {
    // pub fn labelledSeqProduct(x: []u32, l: []u32, shift: u32, WINDOW_LEN: u32) u64 {
    // pub fn get_sequence_self_overlaps(alloc: *Allocator, original: []const u32) !self_overlap_results {
    var overlaps = try get_sequence_self_overlaps(alloc, x);
    // TODO: Why are these double-frees? Where the hell else are they getting freed?
    // defer std.testing.allocator.free(overlaps.shifts);
    // defer std.testing.allocator.free(overlaps.next_is);

    // std.debug.print("overlaps: {}\n", .{overlaps.shifts.len});

    var shift_scores = std.ArrayList(u64).init(alloc);
    defer shift_scores.deinit();

    const window_length = 100;

    var max_score: u64 = 0;
    var max_score_i: usize = 0;
    var max_score_shift: u32 = 0;
    for (overlaps.shifts) |overlap, i| {
        if (overlap <= window_length) continue;

        var score = labelledSeqProduct(x, l, overlap, window_length) * overlap;
        if (score > max_score) {
            max_score = score;
            max_score_i = i;
            max_score_shift = overlap;
        }
        try shift_scores.append(score);
        if (verbose) std.debug.print("Shift: {}, power: {}\n", .{ overlap, score });
    }

    if (verbose) {
        std.debug.print("sequence len: {}\n", .{x.len});
        std.debug.print("max score: {}, i: {}\n", .{ max_score, max_score_i });
    }

    const result: GetPeriodicityResult = .{
        .periodicity_power = max_score,
        .periodicity = max_score_shift,
    };
    return result;
}

test "periodicity test" {
    const noteEvents = (try parseNoteFile(std.testing.allocator, test_file));
    defer std.testing.allocator.free(noteEvents);
    std.debug.warn("noteEvents.len: {}\n", .{noteEvents.len});

    var note_ons = std.ArrayList(u32).init(std.testing.allocator);
    defer note_ons.deinit();

    var notes = std.ArrayList(u32).init(std.testing.allocator);
    defer notes.deinit();

    for (noteEvents) |note| {
        if (note.note_type == NoteType.note_on) {
            try note_ons.append(note.note_time);
            try notes.append(note.note);
        }
    }

    var periodicity = try getPeriodicity(std.testing.allocator, note_ons.items, notes.items);

    std.debug.print("power: {}, periodicity: {}\n", periodicity);
    std.debug.print("log periodicity: {}\n", .{@log10(@intToFloat(f64, periodicity.periodicity))});
}

const GetRoughPeriodicityResult = struct {
    shifts: []u32,
    /// Autocorrelation values for each shift
    acorrs: []u64,
};

/// Get periodicity power for points in the shift sequence separated by delta
/// (get's the nearest points that are in the shift sequence using greatest-lower-bound)
/// This is an optimization so we don't have to calculate autocorrelation for every shift
///
/// Caller owns results
pub fn getRoughPeriodicity(alloc: *Allocator,
                           x: []u32,
                           l: []u32,
                           overlaps: self_overlap_results,
                           delta: u32,
                           window_length: u32) !GetRoughPeriodicityResult {
    var shifts = std.ArrayList(u32).init(alloc);
    defer shifts.deinit();
    var acorrs = std.ArrayList(u64).init(alloc);
    defer acorrs.deinit();
    
    var shift_i: u32 = 0;
    while(shift_i < overlaps.shifts.len) {
        const shift = overlaps.shifts[shift_i];
        var acorr = labelledSeqProduct(x, l, shift, window_length) * shift;
            
        try acorrs.append(acorr);
        try shifts.append(shift);

        // increment to next shift we want to calculate
        const new_shift_i = glbi(overlaps.shifts, overlaps.shifts[shift_i] + delta);
        if(new_shift_i) |new| {
            shift_i = if (new == shift_i) shift + 1 else new;
        } else unreachable;
    }

    var shifts_out = try alloc.alloc(u32, shifts.items.len);
    std.mem.copy(u32, shifts_out, shifts.items);

    var acorrs_out = try alloc.alloc(u64, acorrs.items.len);
    std.mem.copy(u64, acorrs_out, acorrs.items);

    const result: GetRoughPeriodicityResult = .{
        .shifts = shifts_out,
        .acorrs = acorrs_out,
    };
    return result;
}

test "rough periodicity test" {
    const noteEvents = (try parseNoteFile(std.testing.allocator, test_file));
    defer std.testing.allocator.free(noteEvents);
    std.debug.warn("noteEvents.len: {}\n", .{noteEvents.len});

    var note_ons = std.ArrayList(u32).init(std.testing.allocator);
    defer note_ons.deinit();

    var notes = std.ArrayList(u32).init(std.testing.allocator);
    defer notes.deinit();

    for (noteEvents) |note| {
        if (note.note_type == NoteType.note_on) {
            try note_ons.append(note.note_time);
            try notes.append(note.note);
        }
    }

    var overlaps = try get_sequence_self_overlaps(std.testing.allocator, note_ons.items);
    defer std.testing.allocator.free(overlaps.shifts);
    defer std.testing.allocator.free(overlaps.next_is);

    var roughPeriodicity = try getRoughPeriodicity(std.testing.allocator, note_ons.items, notes.items, overlaps, 50, 100);
    defer std.testing.allocator.free(roughPeriodicity.shifts);
    defer std.testing.allocator.free(roughPeriodicity.acorrs);

    for (roughPeriodicity.shifts) |shift, i| {
        std.debug.print("{}: shift: {}, acorr: {}\n", .{ i, shift, roughPeriodicity.acorrs[i] });
    }
}

pub fn getFinePeriodicity(alloc: *Allocator, x: []u32, l: []u32, overlaps: self_overlap_results, delta: u32, window_length: u32) !GetPeriodicityResult {
    const shifts = overlaps.shifts;
    var rough_periodicity = try getRoughPeriodicity(alloc, x, l, overlaps, delta, window_length);
    defer alloc.free(rough_periodicity.shifts);
    defer alloc.free(rough_periodicity.acorrs);
    const rough_shifts = rough_periodicity.shifts;

    // Find max acorrelation on the rough pass to see where we need to search for the actual max
    var max_acorr: u64 = 0;
    var max_acorr_i: u32 = 0;
    for (rough_shifts) |shift, i| {
        if(verbose) std.debug.print("rough periodicity shift[{}]: {}, acorr: {}\n", .{i, shift, rough_periodicity.acorrs[i]});
        if (rough_periodicity.acorrs[i] > max_acorr) {
            max_acorr = rough_periodicity.acorrs[i];
            max_acorr_i = @intCast(u32, i);
        }
    }
    if (verbose)
        std.debug.print("rough_max_acorr: {}\nrough_max_acorr_i: {}\n", .{ max_acorr, max_acorr_i });

    // Search the region surrounding the max from the rough periodicity check
    var start_i = if (max_acorr_i > 0) max_acorr_i - 1 else 0;
    if (glbi(shifts, rough_shifts[start_i])) |start_index| {
        if (glbi(shifts, rough_shifts[std.math.min(rough_shifts.len - 1, max_acorr_i + 1)])) |end_index| {
            if(verbose) {
                std.debug.print("rough_shifts[max_acorr_i]: {}\n", .{rough_shifts[max_acorr_i]});
                std.debug.print("start_index: {}\nend_index: {}\n", .{start_index, end_index});
                std.debug.print("shifts[start_index]: {}\nshifts[end_index]: {}\n", .{shifts[start_index], shifts[end_index]});
            }

            var fine_max_acorr: u64 = max_acorr;
            var fine_max_acorr_i: u32 = max_acorr_i;
            var i: u32 = start_index;
            while (i <= end_index) : (i += 1) {
                const overlap = overlaps.shifts[i];

                var acorr = labelledSeqProduct(x, l, overlap, window_length) * overlap;
                if (acorr > fine_max_acorr) {
                    fine_max_acorr = acorr;
                    fine_max_acorr_i = i;
                }
            }
            if(verbose) std.debug.print("Shift: {}, power: {}\n", .{ overlaps.shifts[fine_max_acorr_i], fine_max_acorr });

            const result: GetPeriodicityResult = .{
                .periodicity_power = fine_max_acorr,
                .periodicity = overlaps.shifts[fine_max_acorr_i],
            };
            return result;
        } else unreachable;
    } else unreachable;
}

test "fine periodicity test" {
    const noteEvents = (try parseNoteFile(std.testing.allocator, test_file));
    defer std.testing.allocator.free(noteEvents);
    std.debug.warn("noteEvents.len: {}\n", .{noteEvents.len});

    var note_ons = std.ArrayList(u32).init(std.testing.allocator);
    defer note_ons.deinit();

    var notes = std.ArrayList(u32).init(std.testing.allocator);
    defer notes.deinit();

    for (noteEvents) |note| {
        if (note.note_type == NoteType.note_on) {
            try note_ons.append(note.note_time);
            try notes.append(note.note);
        }
    }

    var time1 = std.time.nanoTimestamp();

    var overlaps = try get_sequence_self_overlaps(std.testing.allocator, note_ons.items);
    defer std.testing.allocator.free(overlaps.shifts);
    defer std.testing.allocator.free(overlaps.next_is);

    var fine_periodicity = try getFinePeriodicity(std.testing.allocator, note_ons.items, notes.items, overlaps, 50, 100);

    var time2 = std.time.nanoTimestamp();

    var periodicity = try getPeriodicity(std.testing.allocator, note_ons.items, notes.items);

    var time3 = std.time.nanoTimestamp();
    std.debug.print("time2-time1: {} ns\n", .{time2 - time1});
    std.debug.print("time3-time2: {} ns\n", .{time3 - time2});
    std.debug.print("fine power: {}, periodicity: {}\n", fine_periodicity);
    std.debug.print("power: {}, periodicity: {}\n", periodicity);
}

pub fn main() !void {
    var args = std.process.args();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &gpa.allocator;
    var i: u8 = 0;

    alloc.free(try (args.next(alloc) orelse return));

    const path: [:0]u8 = try (args.next(alloc) orelse return);
    defer alloc.free(path);

    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    const buf = try file.readToEndAlloc(alloc, 1048576);

    const noteEvents = (try parseNoteFile(std.testing.allocator, buf));
    defer std.testing.allocator.free(noteEvents);
    std.debug.warn("noteEvents.len: {}\n", .{noteEvents.len});

    var note_ons = std.ArrayList(u32).init(std.testing.allocator);
    defer note_ons.deinit();

    var notes = std.ArrayList(u32).init(std.testing.allocator);
    defer notes.deinit();

    for (noteEvents) |note| {
        if (note.note_type == NoteType.note_on) {
            try note_ons.append(note.note_time);
            try notes.append(note.note);
        }
    }

    var periodicity = try getPeriodicity(std.testing.allocator, note_ons.items, notes.items);

    std.debug.print("power: {}, periodicity: {}\n", periodicity);
    std.debug.print("log periodicity: {}\n", .{@log10(@intToFloat(f64, periodicity.periodicity))});
}
