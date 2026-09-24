const std = @import("std");

// In Zig, when we declare a struct, we are declaring a Namespace and a Type.
// A struct with no field is only use as a namespace.
const Point = struct {
    // field -> this is the "value" part
    x: i64,

    // no self -> namespace function, called on the type
    pub fn origin() Point {
        return .{ .x = 0 };
    }

    // declaration (not a field) -> shared by all Points, costs no memory
    // kind is using Point as namespace.
    pub const kind = "point";
    pub const kind2 = "point";

    // has self -> method, called on value
    pub fn double(self: Point) i64 {
        return 2 * self.x;
    }
};

fn Mixin(comptime T: type) type {
    return struct {
        pub fn describe(self: T) void {
            std.debug.print("{d}\n", .{self.x});
        }
    };
}

pub fn main() !void {
    const p = Point.origin(); // -> calling through the type
    _ = p.double(); // -> method, called on value
    std.debug.print("{s}\n", .{Point.kind});
    //std.debug.print("{s}", .{o.kind}); // won't compile because it looks for a field "kind"
    std.debug.print("{d}\n", .{@sizeOf(Point)}); // having kind or kind2 doesn't change it, sizeof is the memory used by fields

    const DescPoint = Mixin(Point);
    DescPoint.describe(p);
    //p.describe(); // won't compile because there is no describe in Point namespace.
}
