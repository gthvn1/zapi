const Self = @This();

const std = @import("std");

// XAPI Grammar contains many types:
//
//   == XAPI -> Zig proposal
//   - string -> []const u8                              -- builtin
//   - int -> i64                                        -- builtin
//   - float -> f64                                      -- builtin
//   - bool -> bool                                      -- builtin
//   - datetime -> []const u8 ?                          -- builtin
//   - void -> void                                      -- builtin
//   - X ref -> the class (e.g. Vm)                      -- postfix, we read it as "ref X"
//   - X record -> a struct generated from class fields, -- postfix
//   - T set -> []T                                      -- postfix
//   - T option -> ?T                                    -- postfix
//   - enum X -> a Zig enum                              -- prefix, here we read it as enum X
//   - (K -> V) map -> ???                               -- postfix
//
// It is recursive: string set set , (VM ref -> (string -> string) map) map ...
// So we cannot use a lookup table like the one used for Stub.
//
// Here is an example of what we want.
// - "string option": we want to generate the tree: option -> string
//   string is a builtin so it is a leaf.
// - "enum task_allowed_operations set": we want to generate: set -> enum "task_allowed_operations"
// - "subject record": we produce: record "subject"
// - "(VM ref -> string set) map":
//   A map has a key and a value. So here we want:
//                  map
//                 /  \
//           ref VM   set
//                     \
//                    string

arena: std.heap.ArenaAllocator,

pub const AstNode = union(enum) {
    // simple type (they carry no information)
    string: void,
    int: void,
    float: void,
    bool: void,
    datetime: void,
    void: void,
    // postfix
    ref: []const u8,
    record: []const u8,
    set: *const AstNode,
    option: *const AstNode,
    map: struct { key: *AstNode, value: *AstNode },
    // prefix
    @"enum": []const u8,
};

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .arena = std.heap.ArenaAllocator.init(gpa),
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn parseType(self: *Self, input: []const u8) !AstNode {
    const a = self.arena.allocator();

    if (std.mem.eql(u8, input, "string")) return .string;
    if (std.mem.eql(u8, input, "int")) return .int;
    if (std.mem.eql(u8, input, "float")) return .float;
    if (std.mem.eql(u8, input, "bool")) return .bool;
    if (std.mem.eql(u8, input, "datetime")) return .datetime;
    if (std.mem.eql(u8, input, "void")) return .void;

    // If it is not a basic type, we read the end of the string and
    // check if it is a postfix value.
    if (std.mem.findScalarLast(u8, input, ' ')) |idx| {
        if (std.mem.eql(u8, input[idx + 1 ..], "ref")) {
            return .{ .ref = input[0..idx] };
        } else if (std.mem.eql(u8, input[idx + 1 ..], "record")) {
            return .{ .record = input[0..idx] };
        } else if (std.mem.eql(u8, input[idx + 1 ..], "set")) {
            const ast_node = try a.create(AstNode);
            ast_node.* = try self.parseType(input[0..idx]);
            return .{ .set = ast_node };
        } else if (std.mem.eql(u8, input[idx + 1 ..], "option")) {
            const ast_node = try a.create(AstNode);
            ast_node.* = try self.parseType(input[0..idx]);
            return .{ .option = ast_node };
        } else if (std.mem.eql(u8, input[idx + 1 ..], "map")) {
            @panic("TODO: map");
        }
    }

    // If it is not basicn and not postfix type, check prefix
    if (std.mem.findScalar(u8, input, ' ')) |idx| {
        if (std.mem.eql(u8, input[0..idx], "enum")) {
            return .{ .@"enum" = input[idx + 1 ..] };
        }
    }

    return error.unknownType;
}

test "test simple cases" {
    var tp = Self.init(std.testing.allocator);
    defer tp.deinit();

    try std.testing.expectEqual(
        AstNode.string,
        try tp.parseType("string"),
    );
}

test "test postfix cases" {
    var tp = Self.init(std.testing.allocator);
    defer tp.deinit();

    try std.testing.expectEqualDeep(
        AstNode{ .ref = "session" },
        try tp.parseType("session ref"),
    );

    try std.testing.expectEqualDeep(
        AstNode{ .option = &AstNode{ .string = {} } },
        try tp.parseType("string option"),
    );
}

test "test prefix cases" {
    var tp = Self.init(std.testing.allocator);
    defer tp.deinit();

    try std.testing.expectEqualDeep(
        AstNode{ .@"enum" = "task_allowed_operations" },
        try tp.parseType("enum task_allowed_operations"),
    );
}
