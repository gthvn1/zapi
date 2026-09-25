const std = @import("std");

// The goal of the tool is too insert the code between tags
// int the Readme.md.
// Anchors are <- BEGIN_CODE path --> and <-- END_CODE path -->.
// This file can be run when the code is build, and we will
// have an uptodate README

pub fn main(init: std.process.Init) !void {
    // For debug purpose we can use stdout for printing
    var out_buf: [1024]u8 = undefined;
    var out_file: std.Io.File.Writer = .init(std.Io.File.stdout(), init.io, &out_buf);
    const stdout = &out_file.interface;

    // Get the filename from the arguments
    var args_it = init.minimal.args.iterate();
    // First parameter is the name of the program, skip it
    _ = args_it.next();
    // Now we are expecting the name of the file to read
    const fname = args_it.next() orelse return error.FileNameIsMissing;
    try stdout.print("input: {s}\n", .{fname});

    // We need a file reader for fname
    const f = try std.Io.Dir.openFile(std.Io.Dir.cwd(), init.io, fname, .{});
    defer f.close(init.io);

    var fbuf: [1024]u8 = undefined;
    var freader = f.reader(init.io, &fbuf);
    const fin = &freader.interface;

    // We will write the new file in "content".
    var content: std.Io.Writer.Allocating = .init(init.gpa);
    defer content.deinit();

    var outside_block = true;

    while (try fin.takeDelimiter('\n')) |line| {
        if (std.mem.find(u8, line, "<!-- BEGIN_CODE")) |_| {
            // TODO: extract the name of the file
            try content.writer.print("{s}\n", .{line});
            try content.writer.writeAll("```zig\n");
            outside_block = false;
            // TODO: copy the content of the code
            continue;
        }

        if (std.mem.find(u8, line, "<!-- END_CODE")) |_| {
            // TODO: check that name is matching the BEGIN CODE
            try content.writer.writeAll("```\n");
            try content.writer.print("{s}\n", .{line});
            outside_block = true;
            continue;
        }

        if (outside_block) {
            try content.writer.print("{s}\n", .{line});
        }
        // if inside block we have nothing to do since we already have the code

    }

    // Currently just print new_out to stdout
    try stdout.writeAll("---\n");
    try stdout.writeAll(content.written());

    // Don't forget to flush
    try stdout.flush();
}
