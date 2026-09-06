const std = @import("std");
const json = std.json;

const raw_api = @import("raw_xapi.zig");

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();

    // First args is the name of the binary, skip it
    _ = args.next();
    const fname = if (args.next()) |arg| arg else return error.NameIsMissing;

    // Read the file
    const contents = try std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        init.io,
        fname,
        init.gpa,
        std.Io.Limit.unlimited,
    );
    defer init.gpa.free(contents);

    // 1. Parse the json.
    const parsed = try json.parseFromSlice(std.json.Value, init.gpa, contents, .{});
    defer parsed.deinit();

    // 2. Extract parsed value into an intermediate representation.
    var rapi = try raw_api.init(init.gpa, parsed.value);
    defer rapi.deinit(init.gpa);
}
