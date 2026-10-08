// Try to understand how we will replace the params in our tool that currenty
// is a list of []const u8 into a more generic params.
//
// live watch: printf "tuple.zig" | entr -c zig run tuple.zig
//
const std = @import("std");

fn readTuple(t: anytype) void {
    std.log.debug("type of t is {any}", .{@TypeOf(t)});
}

pub fn main() void {
    const t = .{ 1, "2", true };
    readTuple(t);
}
