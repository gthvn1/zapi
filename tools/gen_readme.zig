const std = @import("std");

// Inserts the content of source files into a markdown file, between markers:
//
//    <- BEGIN_CODE [path] -->
//    <-- END_CODE [path] -->
//
// The markers are kept, and everything between them is replaced on each run.
// So the tool can be run on every build to keep the Readme.md up to date.
//
// Usage: gen_readme <Readme.md>

const begin_tag = "<!-- BEGIN_CODE";
const end_tag = "<!-- END_CODE";

/// Returns the path between brackets, e.g. "[examples/basic.zig]"
fn extractFileName(str: []const u8) ?[]const u8 {
    // We want to extrat filename under brackets
    _, const after = std.mem.cut(u8, str, "[") orelse return null;
    const fname, _ = std.mem.cut(u8, after, "]") orelse return null;
    return std.mem.trim(u8, fname, " \t");
}

fn insertCode(w: *std.Io.Writer, io: std.Io, code: []const u8) !void {
    const f = try std.Io.Dir.cwd().openFile(io, code, .{});
    defer f.close(io);
    var fbuf: [1024]u8 = undefined;
    var freader = f.reader(io, &fbuf);

    _ = try freader.interface.streamRemaining(w);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    // Get the filename from the arguments
    var args_it = init.minimal.args.iterate();
    _ = args_it.next(); // First parameter is the name of the program, skip it
    // Now we are expecting the name of the file to read
    const fname = args_it.next() orelse return error.FileNameIsMissing;

    // Read the whole file at once. Every line is then a slice into `fcontent`,
    // which lives until the end of the main: no line can be overwritten, so
    // nothing needs to be duplicated.
    const fcontent = blk: {
        const f = try std.Io.Dir.cwd().openFile(io, fname, .{});
        defer f.close(io);
        var fbuf: [1024]u8 = undefined;
        var freader = f.reader(io, &fbuf);
        break :blk try freader.interface.allocRemaining(gpa, .unlimited);
    };
    defer gpa.free(fcontent);

    // We will write the new file in "content".
    var out: std.Io.Writer.Allocating = .init(gpa);
    defer out.deinit();
    const w = &out.writer;

    var code_block: ?[]const u8 = null;

    // Drop final \n to avoid extras empty lines
    const body = if (std.mem.endsWith(u8, fcontent, "\n")) fcontent[0 .. fcontent.len - 1] else fcontent;
    var lines = std.mem.splitScalar(u8, body, '\n');

    while (lines.next()) |line| {
        // Markers must start the line, so a Readme that *mentions* a marker
        // in its text is not affected.
        const trimmed = std.mem.trim(u8, line, " \t\r");

        if (std.mem.startsWith(u8, trimmed, begin_tag)) {
            if (code_block != null) return error.NestedCodeBlockUnsupported;
            const code_path = extractFileName(trimmed) orelse return error.FailedToReadCodeFromBegin;

            // We keep the begin tag
            try w.print("{s}\n", .{line});
            try w.writeAll("```zig\n");
            try insertCode(w, io, code_path);
            // Don't add the closing fence to the last line of code.
            if (!std.mem.endsWith(u8, out.written(), "\n")) try w.writeByte('\n');
            try w.writeAll("```\n");

            code_block = code_path;
        } else if (std.mem.startsWith(u8, trimmed, end_tag)) {
            const expected_path = code_block orelse return error.EndBlockWithoutBeginBlock;
            const code_path = extractFileName(trimmed) orelse return error.FailedToReadCodeFromEnd;
            if (!(std.mem.eql(u8, code_path, expected_path))) return error.MatchingFailedWithEndCode;
            // Keep the end tag
            try w.print("{s}\n", .{line});
            code_block = null;
        } else if (code_block == null) {
            try w.print("{s}\n", .{line});
        }
        // if inside block we have nothing to do since we already have the code
    }

    if (code_block != null) return error.BeginBlockWithoutEndBlock;

    // Only touch the file if something changed.
    if (std.mem.eql(u8, out.written(), fcontent)) return;

    // Update the file
    const f = try std.Io.Dir.cwd().createFile(io, fname, .{});
    defer f.close(io);

    var buf: [4096]u8 = undefined;
    var fw: std.Io.File.Writer = .init(f, io, &buf);
    try fw.interface.writeAll(out.written());
    try fw.interface.flush(); // Don't forget to flush
}
