const std = @import("std");

const midilib = @cImport(@cInclude("midifile.h"));

const os = std.os;
const Allocator = std.mem.Allocator;

test "nothing to see here" {
    try readMidiFile(std.testing.allocator);
}

pub fn readMidiFile(alloc: *Allocator) !void {
    const dir: std.fs.Dir = std.fs.cwd();
    const path = try std.fs.realpathAlloc(alloc, ".");
    defer alloc.free(path);
    std.debug.print("cwd: {}", .{path});

    const file: std.fs.File = try dir.openFile("test.txt", .{.read=true});
    defer file.close();

    const reader = file.reader;

    const midi_file = midilib.midiFileCreate("test.mid", 1);   
}
