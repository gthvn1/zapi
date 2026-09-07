const Self = @This();

const std = @import("std");
const json = std.json;

pub const ClassInfo = struct {
    name: []const u8,
    fields: []FieldInfo,
    messages: []MessageInfo,
};

pub const FieldInfo = struct {
    name: []const u8,
    type: []const u8,
};

pub const MessageInfo = struct {
    name: []const u8,
    params: []MessageInfoParam,
    result: []const u8,
};

pub const MessageInfoParam = struct {
    name: []const u8,
    type: []const u8,
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
            const fields_arr = object.get("fields") orelse return error.fieldsIsMissing;
            const fields = try parse_fields(a, fields_arr);

            // all object should have messages that is an array
            const messages_arr = object.get("messages") orelse return error.messagesIsMissing;
            const messages = try parse_messages(a, messages_arr);

            std.debug.print("}}\n", .{});

            try self.root.append(a, .{ .name = name.string, .fields = fields, .messages = messages });
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

fn parse_messages(a: std.mem.Allocator, messages: std.json.Value) ![]MessageInfo {
    const m: []MessageInfo = try a.alloc(MessageInfo, messages.array.items.len);

    std.debug.print("  messages:\n", .{});
    for (messages.array.items, m) |item, *slot| {
        const object: std.json.ObjectMap = item.object;

        const name = object.get("name") orelse return error.msgNameIsMissing;
        std.debug.print("    ({s}", .{name.string});

        const params_val = object.get("params") orelse return error.failedParseMessageParams;
        const params = try parse_msg_params(a, params_val);

        const result_val = object.get("result") orelse return error.failedParseMessageResult;
        const result = try parse_msg_result(result_val);

        slot.* = .{ .name = name.string, .params = params, .result = result };
    }

    return m;
}

fn parse_msg_params(a: std.mem.Allocator, params: std.json.Value) ![]MessageInfoParam {
    const p: []MessageInfoParam = try a.alloc(MessageInfoParam, params.array.items.len);

    for (params.array.items, p) |item, *slot| {
        const object: std.json.ObjectMap = item.object;
        const name = object.get("name") orelse return error.paramNameIsMissing;
        const ty = object.get("type") orelse return error.paramTypeIsMissing;

        std.debug.print(", {s}:", .{name.string});
        std.debug.print("{s}", .{ty.string});

        slot.* = .{ .name = name.string, .type = ty.string };
    }

    return p;
}

fn parse_msg_result(result: std.json.Value) ![]const u8 {
    const arr = switch (result) {
        .array => |arr| arr,
        else => return error.resultIsNotAnArray,
    };
    const res = if (arr.items.len == 0) arr.items[0] else return error.resultIsEmpty;

    std.debug.print(", {s})\n", .{res.string});
    return res.string;
}
