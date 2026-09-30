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
    return .{
        .root = std.ArrayList(ClassInfo).empty,
        .arena = std.heap.ArenaAllocator.init(gpa),
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn dump(self: *Self, writer: *std.Io.Writer) !void {
    try writer.print("There are {} class\n", .{self.root.items.len});
    for (self.root.items) |class_info| {
        try writer.print("ClassInfo: {s}\n", .{class_info.name});
        try writer.print("  Fields:\n", .{});
        for (class_info.fields) |field| {
            try writer.print("    {s}/{s}\n", .{ field.name, field.type });
        }
        try writer.print("  Messages:\n", .{});
        for (class_info.messages) |msg| {
            try writer.print("    {s} (", .{msg.name});
            for (msg.params, 0..) |param, idx| {
                if (idx != 0)
                    try writer.print(", {s}:{s}", .{ param.name, param.type })
                else
                    try writer.print("{s}:{s}", .{ param.name, param.type });
            }
            try writer.print(") -> {s}\n", .{msg.result});
        }
    }
}

pub fn parse(self: *Self, root: std.json.Value) !void {
    const a = self.arena.allocator();

    // The top level JSON Value is one array.
    // The array contains object that are objectMap.
    switch (root) {
        .array => for (root.array.items) |item| {
            const object: std.json.ObjectMap = item.object;

            const name = object.get("name") orelse return error.ClassNameIsMissing;

            // all object should have a field that is an array
            const fields_arr = object.get("fields") orelse return error.FieldsIsMissing;
            const fields = try parse_fields(a, fields_arr);

            // all object should have messages that is an array
            const messages_arr = object.get("messages") orelse return error.MessagesIsMissing;
            const messages = try parse_messages(a, messages_arr);

            try self.root.append(a, .{ .name = name.string, .fields = fields, .messages = messages });
        },
        else => return error.RootIsNotAnArray,
    }
}

fn parse_fields(a: std.mem.Allocator, fields: std.json.Value) ![]FieldInfo {
    const f: []FieldInfo = try a.alloc(FieldInfo, fields.array.items.len);

    for (fields.array.items, f) |item, *slot| {
        const object: std.json.ObjectMap = item.object;
        const name = object.get("name") orelse return error.FieldNameIsMissing;
        const ty = object.get("type") orelse return error.FieldTypeIsMissing;

        slot.* = .{ .name = name.string, .type = ty.string };
    }

    return f;
}

fn parse_messages(a: std.mem.Allocator, messages: std.json.Value) ![]MessageInfo {
    const m: []MessageInfo = try a.alloc(MessageInfo, messages.array.items.len);

    for (messages.array.items, m) |item, *slot| {
        const object: std.json.ObjectMap = item.object;

        const name = object.get("name") orelse return error.MsgNameIsMissing;

        const params_val = object.get("params") orelse return error.FailedParseMessageParams;
        const params = try parse_msg_params(a, params_val);

        const result_val = object.get("result") orelse return error.FailedParseMessageResult;
        const result = try parse_msg_result(result_val);

        slot.* = .{ .name = name.string, .params = params, .result = result };
    }

    return m;
}

fn parse_msg_params(a: std.mem.Allocator, params: std.json.Value) ![]MessageInfoParam {
    const p: []MessageInfoParam = try a.alloc(MessageInfoParam, params.array.items.len);

    for (params.array.items, p) |item, *slot| {
        const object: std.json.ObjectMap = item.object;
        const name = object.get("name") orelse return error.ParamNameIsMissing;
        const ty = object.get("type") orelse return error.ParamTypeIsMissing;

        slot.* = .{ .name = name.string, .type = ty.string };
    }

    return p;
}

fn parse_msg_result(result: std.json.Value) ![]const u8 {
    const arr = switch (result) {
        .array => |arr| arr,
        else => return error.ResultIsNotAnArray,
    };
    const res = if (arr.items.len > 0) arr.items[0] else return error.ResultIsEmpty;

    return res.string;
}
