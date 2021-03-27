const std = @import("std");

const mecha = @import("mecha/mecha.zig");

const os = std.os;
const Allocator = std.mem.Allocator;

const contents = 
\\note_on	66	185	67
\\note_on	66	185	67
\\note_off	67	235	104
\\note_on	58	406	59
\\note_off	66	432	101
\\note_off	50	452	106
\\note_on	66	548	43
\\note_off	66	654	96
\\note_on	66	777	41
\\note_on	51	784	64
\\note_off	58	807	101
;

test "nothing to see here" {
    try readNoteFile(std.testing.allocator, contents);
}

const tab = mecha.utf8.char('\t');
const noteLine = mecha.oneOf(.{noteOnLine, noteOffLine});
const noteFileParser = mecha.many(noteLine, .{.collect = false, .separator = mecha.utf8.char('\n')});
const noteOnLine = mecha.combine( . {
    mecha.string("note_on"),
    tab,
    mecha.int(u16, 10),
    tab,
    mecha.int(u16, 10),
    tab,
    mecha.int(u16, 10),
});

const noteOffLine = mecha.combine( . {
    mecha.string("note_off"),
    tab,
    mecha.int(u16, 10),
    tab,
    mecha.int(u16, 10),
    tab,
    mecha.int(u16, 10),

});

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
