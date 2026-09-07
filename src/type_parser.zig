const Self = @This();

const std = @import("std");

pub const TypeKind = enum { builtin, class, @"enum", @"opaque", cons };

pub fn simple_test() usize {
    return 42;
}
