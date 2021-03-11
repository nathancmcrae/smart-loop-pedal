const std = @import("std");

const midilib = @cImport({
    @cInclude("midifile.h");
    @cInclude("midiinfo.h");
});

const mecha = @import("mecha")

const os = std.os;
const Allocator = std.mem.Allocator;

test "nothing to see here" {
    try readMidiFile(std.testing.allocator);
    std.debug.warn("I'm a statement in a test", .{});
}

test "allanotherless test " {
    std.debug.warn("I'm a statement in a test", .{});
}

pub fn readMidiFile(alloc: *Allocator) !void {
    std.debug.warn("I'm up here", .{});
    std.debug.warn("Also here", .{});
    const midi_file = midilib.midiFileOpen("test.mid");
    std.debug.warn("but not here", .{});

    var msg: midilib.MIDI_MSG = .{
        .iType = @intToEnum(midilib.tMIDI_MSG, midilib.msgNoteOff),
        .dt = 0,
        .dwAbsPos = 0,
        .iMsgSize = 0,
        .bImpliedMsg = 0,
        .iImpliedMsg = @intToEnum(midilib.tMIDI_MSG, midilib.msgNoteOff),
        .data = 0,
        .data_sz = 0,
        .MsgData = .{
            .NoteOff = .{
                .iNote = 0,
                .iChannel = 0,
            }
        },
        .iLastMsgType = @intToEnum(midilib.tMIDI_MSG, midilib.msgNoteOff),
        .iLastMsgChnl = 0,
    };

    std.debug.print("I'm here", .{});
    midilib.midiReadInitMessage(&msg);
    std.debug.print("I'm there", .{});
    const iNum = midilib.midiReadGetNumTracks(midi_file);
    std.debug.print("Num tracks: {}", .{iNum});
    std.debug.warn("I'm up here", .{});
}

pub fn readNoteFile(alloc: *Allocator) {
    const tab = mecha.token(mecha.utf8.char('\t'));
    const noteOnLine = mecha.combine( . {
        mecha.token(mecha.string("note_on")),
        tab,
        mecha.int(u8, 10),
        tab,
        mecha.int(u8, 10),
        tab,
        mecha.int(u8, 10),
        mecha.token(mecha.utf8.char('\n')),
    });

    const noteOnLine = mecha.combine( . {
        mecha.token(mecha.string("note_off")),
        tab,
        mecha.int(u8, 10),
        tab,
        mecha.int(u8, 10),
        tab,
        mecha.int(u8, 10),
        mecha.token(mecha.utf8.char('\n')),
    });
    const noteLine = mecha.oneOf(.{noteOnLine, noteOffLine});
    const noteFileParser = mecha.many(noteLine);

    
}
