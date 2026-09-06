const std = @import("std");
const json = std.json;

const ast = @import("xapi_ast.zig");

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();

    // First args is the name of the binary, skip it
    _ = args.next();
    const fname = if (args.next()) |arg| arg else return error.NameIsMissing;

    // read the file
    const contents = try std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        init.io,
        fname,
        init.gpa,
        std.Io.Limit.unlimited,
    );
    defer init.gpa.free(contents);

    // parse the json
    const parsed = try json.parseFromSlice(std.json.Value, init.gpa, contents, .{});
    defer parsed.deinit();

    try ast.parse_api(parsed.value);
}
