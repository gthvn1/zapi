const Self = @This();

const std = @import("std");
const json = std.json;

pub const FieldInfo = struct {
    name: []const u8,
    type: []const u8,
};

pub const ClassInfo = struct {
    name: []const u8,
    fields: []FieldInfo,
};

root: std.ArrayList(ClassInfo),
arena: std.heap.ArenaAllocator,

pub fn init(gpa: std.mem.Allocator) Self {
    // Just to know the size of struct passed on the stack
    std.debug.print("{d}\n", .{@sizeOf(std.json.Value)});
    return .{
        .root = std.ArrayList(ClassInfo).empty,
        .arena = std.heap.ArenaAllocator.init(gpa),
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn parse(self: *Self, root: std.json.Value) !void {
    // Just to know the size of struct passed on the stack
    std.debug.print("{d}\n", .{@sizeOf(std.json.Value)});
    const a = self.arena.allocator();

    // The top level JSON Value is one array.
    // The array contains object that are objectMap.
    switch (root) {
        .array => for (root.array.items, 1..) |item, id| {
            const object: std.json.ObjectMap = item.object;

            const name = object.get("name") orelse return error.nameIsMissing;
            std.debug.print("ClassInfo:\n{{\n  id: {d}, name: {s}\n", .{ id, name.string });

            // all object should have a field that is an array
            const fields = if (object.get("fields")) |fields_array|
                try parse_fields(a, fields_array)
            else
                return error.fieldsIsMissing;

            // all object should have messages that is an array
            if (object.get("messages")) |messages_array| {
                try parse_messages(messages_array);
            } else return error.messagesIsMissing;
            std.debug.print("}}\n", .{});

            try self.root.append(a, .{
                .name = name.string,
                .fields = fields,
            });
        },
        else => return error.rootIsNotAnArray,
    }
}

fn parse_fields(a: std.mem.Allocator, fields: std.json.Value) ![]FieldInfo {
    const f: []FieldInfo = try a.alloc(FieldInfo, fields.array.items.len);

    std.debug.print("  fields:\n", .{});
    for (fields.array.items, f) |item, *slot| {
        const object: std.json.ObjectMap = item.object;
        const name = object.get("name") orelse return error.fieldNameIsMissing;
        const ty = object.get("type") orelse return error.fieldTypeIsMissing;

        std.debug.print("    ({s}", .{name.string});
        std.debug.print(", {s})\n", .{ty.string});

        slot.* = .{ .name = name.string, .type = ty.string };
    }

    return f;
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
