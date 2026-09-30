const Self = @This();

const std = @import("std");

arena: std.heap.ArenaAllocator,

pub const AstType = enum { builtin, @"enum", class, ref };
pub const AstNode = union(AstType) {
    builtin: []const u8,
    @"enum": []const u8,
    class: []const u8,
    ref: *AstNode,
};

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .arena = std.heap.ArenaAllocator.init(gpa),
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn parse_type(self: *Self, input: []const u8) !AstNode {
    const a = self.arena.allocator();

    if ((std.mem.eql(u8, input, "string")) or
        (std.mem.eql(u8, input, "bool")) or
        (std.mem.eql(u8, input, "int")) or
        (std.mem.eql(u8, input, "float")) or
        (std.mem.eql(u8, input, "void")) or
        (std.mem.eql(u8, input, "datetime")))
    {
        return AstNode{ .builtin = input };
    }

    // Enum is at the beginning of the input if any.
    if (std.mem.findScalar(u8, input, ' ')) |idx| {
        if (std.mem.eql(u8, input[0..idx], "enum")) {
            return AstNode{ .@"enum" = input[idx + 1 ..] };
        }
    }

    // Ref is at the end of the string if any
    if (std.mem.findScalarLast(u8, input, ' ')) |idx| {
        if (std.mem.eql(u8, input[idx + 1 ..], "ref")) {
            const ast_node = try a.create(AstNode);
            ast_node.* = try self.parse_type(input[0..idx]);
            return AstNode{ .ref = ast_node };
        }
    }

    // If nothing match it is a class
    return AstNode{ .class = input };
}

test "test bare cases" {
    var tp = Self.init(std.testing.allocator);
    defer tp.deinit();

    try std.testing.expectEqual(tp.parse_type("string"), AstNode{ .builtin = "string" });
    try std.testing.expectEqual(tp.parse_type("bool"), AstNode{ .builtin = "bool" });
    try std.testing.expectEqual(tp.parse_type("int"), AstNode{ .builtin = "int" });
    try std.testing.expectEqual(tp.parse_type("float"), AstNode{ .builtin = "float" });
    try std.testing.expectEqual(tp.parse_type("void"), AstNode{ .builtin = "void" });
    try std.testing.expectEqual(tp.parse_type("datetime"), AstNode{ .builtin = "datetime" });
    try std.testing.expectEqual(tp.parse_type("session"), AstNode{ .class = "session" });
}

test "test enum cases" {
    var tp = Self.init(std.testing.allocator);
    defer tp.deinit();

    const ast_node = try tp.parse_type("enum task_allowed_operations");
    switch (ast_node) {
        .@"enum" => |str| try std.testing.expectEqualStrings(
            "task_allowed_operations",
            str,
        ),
        else => unreachable,
    }
}

test "test ref cases" {
    var tp = Self.init(std.testing.allocator);
    defer tp.deinit();

    const ast_node = try tp.parse_type("session ref");
    switch (ast_node) {
        .ref => |ast| {
            const inner: AstNode = ast.*;
            switch (inner) {
                .class => |str| try std.testing.expectEqualStrings("session", str),
                else => unreachable,
            }
        },
        else => unreachable,
    }
}
