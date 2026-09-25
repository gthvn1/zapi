const std = @import("std");

// The goal of the tool is too insert the code between tags
// int the Readme.md.
// Anchors are <- BEGIN_CODE path --> and <-- END_CODE path -->.
// This file can be run when the code is build, and we will
// have an uptodate README

fn extractFileName(str: []u8) ?[]const u8 {
    // We want to extrat filename under brackets
    _, const after = std.mem.cut(u8, str, "[") orelse return null;
    const fname, _ = std.mem.cut(u8, after, "]") orelse return null;
    return std.mem.trim(u8, fname, " \n");
}

fn insertCode(w: *std.Io.Writer, io: std.Io, code: []const u8) !void {
    // We need a file reader for fname
    const f = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, code, .{});
    defer f.close(io);

    var fbuf: [1024]u8 = undefined;
    var freader = f.reader(io, &fbuf);

    _ = try freader.interface.streamRemaining(w);
}

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

    var code_block: ?[]const u8 = null;

    while (try fin.takeDelimiter('\n')) |line| {
        if (std.mem.find(u8, line, "<!-- BEGIN_CODE")) |_| {
            try content.writer.print("{s}\n", .{line});
            try content.writer.writeAll("```zig\n");
            // TODO: Fix the bug. Currently code_block is a pointer to fbuf and a length. So
            // right now it points to the filename of the code. But later we want to check that
            // end_block is the same filename. But at this time the fbuf will be different and
            // so code_block will be what is at the same address in fbuf but it won't be the
            // filename. So we need to keep a copy here and free it once checked with END_CODE.
            code_block = extractFileName(line) orelse return error.FailedToReadCodeFromBegin;
            try insertCode(&content.writer, init.io, code_block.?);
            continue;
        }

        if (std.mem.find(u8, line, "<!-- END_CODE")) |_| {
            // TODO: check that name is matching the BEGIN CODE
            // Sanity check
            const code = extractFileName(line) orelse return error.FailedToReadCodeFromEnd;
            if ((std.mem.eql(u8, code, code_block.?))) return error.MatchingFailedWithEndCode;
            try content.writer.writeAll("```\n");
            try content.writer.print("{s}\n", .{line});
            code_block = null;
            continue;
        }

        if (code_block == null) {
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
