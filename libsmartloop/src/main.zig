const std = @import("std");
const midi = @import("zig-midi");

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

    const header = try midi.decode.fileHeader(reader);
    
    // const fileSize = try file.getEndPos();

    // var buffer = try alloc.alloc(u8, fileSize);
    // defer alloc.free(buffer);
    // const bytesRead = try file.read(buffer[0..]);
}
