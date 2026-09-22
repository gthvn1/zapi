const std = @import("std");

fn makeName(gpa: std.mem.Allocator) ![]const u8 {
    const big = try gpa.alloc(u8, 1024 * 1024);
    @memset(big, 'A');
    return big[0..5];
}

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();

    const name = try makeName(arena.allocator());
    std.debug.print("name = {s}\n", .{name});
}
