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

pub fn main() void {
    std.debug.print("hello world!\n", .{});
}
