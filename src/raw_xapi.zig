const Self = @This();

const std = @import("std");
const json = std.json;

pub const ClassInfo = struct {
    name: []const u8,
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

    var id: usize = 1;
    // The top level JSON Value is one array.
    // The array contains object that are objectMap.
    switch (root) {
        .array => for (root.array.items) |item| {
            const object: std.json.ObjectMap = item.object;
            if (object.get("name")) |name| {
                try self.root.append(a, ClassInfo{ .name = name.string });
                std.debug.print(
                    "ClassInfo:\n{{\n  id: {d}, name: {s}\n",
                    .{ id, name.string },
                );
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
        },
        else => return error.rootIsNotAnArray,
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
