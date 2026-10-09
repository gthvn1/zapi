// Try to understand how we will replace the params in our tool that currenty
// is a list of []const u8 into a more generic params.
//
// live watch: printf "tuple.zig" | entr -c zig run tuple.zig
//
const std = @import("std");
const log = std.log;
const json = std.json;
const Io = std.Io;

fn tupleToJsonArr(w: *Io.Writer, tuple: anytype) !void {
    var j = std.json.Stringify{ .writer = w };

    try j.beginArray();

    // First write item per item
    try j.beginArray();
    inline for (tuple, 0..) |item, idx| {
        log.debug("type of t[{d}] is {any}", .{ idx, @TypeOf(item) });
        try j.write(item);
    }
    try j.endArray();

    // Or just the tuple
    try j.write(tuple);

    try j.endArray();
}

pub fn main(init: std.process.Init) void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout: Io.File.Writer = .init(Io.File.stdout(), init.io, &stdout_buf);

    const Vm = struct {
        ref: []const u8,
        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.write(self.ref);
        }
    };

    const MyS = struct { ref: []const u8, id: usize };

    const t = .{
        Vm{ .ref = "OpaqueRef:12" },
        MyS{ .ref = "OpaqueRef: 13", .id = 42 },
        1,
        "2",
        true,
    };

    tupleToJsonArr(&stdout.interface, t) catch log.err("Failed to write tuple as JSON", .{});

    stdout.interface.flush() catch log.err("Failed to flush", .{});
}
