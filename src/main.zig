const std = @import("std");
const json = std.json;

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

    // The top level JSON Value is one array.
    // The array contains object that are objectMap.
    for (parsed.value.array.items) |item| {
        const object: std.json.ObjectMap = item.object;
        if (object.get("name")) |name| {
            std.debug.print("Object: {s}\n", .{name.string});
        }
    }
}
