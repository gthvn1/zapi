const std = @import("std");

// The goal of the tool is too insert the code between tags
// int the Readme.md.
// Anchors are <- BEGIN_CODE path --> and <-- END_CODE path -->.
// This file can be run when the code is build, and we will
// have an uptodate README

pub fn main(init: std.process.Init) !void {
    var args_it = init.minimal.args.iterate();
    // First parameter is the name of the program, skip it
    _ = args_it.next();
    // Now we are expecting the name of the file to read
    const fname = args_it.next() orelse return error.FileNameIsMissing;
    std.debug.print("input: {s}\n", .{fname});

    // We need a reader for the file
    const f = try std.Io.Dir.openFile(std.Io.Dir.cwd(), init.io, fname, .{});
    defer f.close(init.io);

    var fbuf: [1024]u8 = undefined;
    var freader = f.reader(init.io, &fbuf);

    const flen = try f.length(init.io);
    std.debug.print("Read {d} bytes\n", .{flen});

    const content = try freader.interface.readAlloc(init.gpa, @as(usize, flen));
    defer init.gpa.free(content);

    const begin_idx = std.mem.find(u8, content, "BEGIN_CODE") orelse return;
    const end_idx = std.mem.find(u8, content, "END_CODE") orelse return error.EndCodeNotFound;

    std.debug.print("Find Begin at offset {d}\n", .{begin_idx});
    std.debug.print("Find End at offset {d}\n", .{end_idx});

    // TODO: we have the offsets, now we probably want to have the begin line and end line to
    // get the name of the function that we need to insert here.
}
