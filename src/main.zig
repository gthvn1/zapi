const std = @import("std");

const AstTypeTag = enum { builtin, ref, set, option, class, @"enum", map, record };

const AstType = union(AstTypeTag) {
    builtin: []const u8,
    ref: *AstType,
    set: *AstType,
    option: *AstType,
    class: []const u8,
    @"enum": []const u8,
    map: struct {
        key_type: *AstType,
        value_type: *AstType,
    },
    record: []struct {
        name: []const u8,
        type: *AstType,
        description: []const u8,
        required: bool,
    },
};

pub fn main(init: std.process.Init) !void {
    var args = init.minimal.args.iterate();

    // First args is the name of the binary, skip it
    _ = args.next();

    const fname = if (args.next()) |arg| arg else return error.NameIsMissing;

    // read the file
    var buffer: [4096]u8 = undefined;
    const contents = try std.Io.Dir.readFile(std.Io.Dir.cwd(), init.io, fname, &buffer);
    var tok = std.mem.tokenizeSequence(u8, contents, "\n");
    while (tok.next()) |line| {
        std.debug.print("line: {s}", .{line});
    }
}
