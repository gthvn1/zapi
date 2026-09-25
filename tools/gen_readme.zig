const std = @import("std");

// The goal of the tool is too insert the code between tags
// int the Readme.md.
// Anchors are <- BEGIN_CODE path --> and <-- END_CODE path -->.
// This file can be run when the code is build, and we will
// have an uptodate README

pub fn main(init: std.process.Init) !void {
    // We are using an arena allocator. As init gives it to us
    // we don't need to free anything.
    const a = init.arena.allocator();

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

    // We will now read the file line by line.
    var content: std.ArrayList([]const u8) = .empty;
    var outside_block = true;

    while (try fin.takeDelimiter('\n')) |line| {
        if (std.mem.find(u8, line, "<!-- BEGIN_CODE")) |_| {
            // TODO: extract the name of the file
            try content.append(a, try std.mem.concat(a, u8, &[_][]const u8{ line, "\n" }));
            try content.append(a, "```zig\n");
            outside_block = false;
            // TODO: copy the content of the code
            continue;
        }

        if (std.mem.find(u8, line, "<!-- END_CODE")) |_| {
            try content.append(a, "```\n");
            try content.append(a, try std.mem.concat(a, u8, &[_][]const u8{ line, "\n" }));
            outside_block = true;
            continue;
        }

        if (outside_block) {
            try content.append(a, try std.mem.concat(a, u8, &[_][]const u8{ line, "\n" }));
        }
        // if inside block we have nothing to do since we already have the code

    }

    // Currently just print new_out to stdout
    try stdout.writeAll("---\n");

    for (content.items) |line| {
        try stdout.writeAll(line);
    }
    // Don't forget to flush
    try stdout.flush();
}
