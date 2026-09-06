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
            std.debug.print("ClassInfo:\n{{\n  id: {d}, name: {s}\n", .{ id, name.string });
        } else return error.nameIsMissing;
        // all object should have a field that is an array
        if (object.get("fields")) |fields_array| {
            try parse_fields(fields_array);
        } else return error.fieldsIsMissing;
        // all object should have messages that is an array
        if (object.get("messages")) |messages_array| {
            try parse_messages(messages_array);
        } else return error.messagesIsMissing;
        std.debug.print("}}\n", .{});
        id += 1;
    }
}

// We are expecting an array
fn parse_fields(fields: std.json.Value) !void {
    std.debug.print("  fields:\n", .{});
    for (fields.array.items) |item| {
        const object: std.json.ObjectMap = item.object;
        if (object.get("name")) |name| {
            std.debug.print("    ({s}", .{name.string});
        } else return error.fieldNameIsMissing;
        if (object.get("type")) |ty| {
            std.debug.print(", {s})\n", .{ty.string});
        } else return error.fieldTypeIsMissing;
    }
}

fn parse_messages(messages: std.json.Value) !void {
    std.debug.print("  messages:\n", .{});
    for (messages.array.items) |item| {
        const object: std.json.ObjectMap = item.object;
        if (object.get("name")) |name| {
            std.debug.print("    ({s}", .{name.string});
        } else return error.msgNameIsMissing;
        if (object.get("params")) |p| {
            try parse_msg_params(p);
        }
        if (object.get("result")) |r| {
            try parse_msg_result(r);
        }
    }
}

fn parse_msg_params(params: std.json.Value) !void {
    for (params.array.items) |item| {
        const object: std.json.ObjectMap = item.object;
        if (object.get("name")) |name| {
            std.debug.print(", {s}:", .{name.string});
        } else return error.paramNameIsMissing;
        if (object.get("type")) |ty| {
            std.debug.print("{s}", .{ty.string});
        } else return error.paramTypeIsMissing;
    }
}

fn parse_msg_result(result: std.json.Value) !void {
    switch (result) {
        .array => {
            const res = result.array.items[0];
            std.debug.print(", {s})\n", .{res.string});
        },
        else => return error.resultIsNotAnArray,
    }
}
