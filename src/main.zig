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

    var id: usize = 1;
    // The top level JSON Value is one array.
    // The array contains object that are objectMap.
    for (parsed.value.array.items) |item| {
        const object: std.json.ObjectMap = item.object;
        if (object.get("name")) |name| {
            std.debug.print("ClassInfo: {{ id: {d}, name: {s}", .{ id, name.string });
        } else return error.nameIsMissing;
        // all object should have a field that is an array
        if (object.get("fields")) |fields_array| {
            _ = fields_array;
            std.debug.print(", fields: ??", .{});
        } else return error.fieldsIsMissing;
        // all object should have messages that is an array
        if (object.get("messages")) |messages_array| {
            _ = messages_array;
            std.debug.print(", messages: ??", .{});
        } else return error.messagesIsMissing;
        std.debug.print("}}\n", .{});
        id += 1;
    }
}
