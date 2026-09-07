const std = @import("std");
const json = std.json;
const Io = std.Io;

const raw_api = @import("raw_xapi.zig");

pub fn main(init: std.process.Init) !void {
    // We will need a writer
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    // We will need an allocator as well
    const gpa = init.gpa;

    var args = init.minimal.args.iterate();

    // First args is the name of the binary, skip it
    _ = args.next();
    const fname = if (args.next()) |arg| arg else return error.NameIsMissing;

    // Read the file
    const contents = try std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), io, fname, gpa, Io.Limit.unlimited);
    defer gpa.free(contents);

    // 1. Parse the json.
    const parsed = try json.parseFromSlice(std.json.Value, gpa, contents, .{});
    defer parsed.deinit();

    // 2. Extract parsed value into an intermediate representation.
    var rapi = raw_api.init(gpa);
    defer rapi.deinit();

    try rapi.parse(parsed.value);
    try rapi.dump(stdout_writer);
    try stdout_writer.flush();
}
