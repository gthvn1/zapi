const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var arena = init.arena;
    defer arena.deinit();
    const a = arena.allocator();

    const params: [2][]const u8 = .{ "hello", "sailor" };
    const body = try writeRpcRequest(a, "Say", &params, 42);

    std.debug.print("JSON size: {d}\n", .{body.len});
    std.debug.print("{s}\n", .{body});

    try parse_response(a, login_failure_response);
}

const login_failure_response =
    "HTTP/1.1 200 OK\r\n" ++
    "content-length: 126\r\n" ++
    "cache-control: no-cache, no-store\r\n" ++
    "content-type: application/json\r\n" ++
    "Access-Control-Allow-Origin: *\r\n" ++
    "Access-Control-Allow-Headers: X-Requested-With\r\n" ++
    "\r\n" ++
    "{\"jsonrpc\":\"2.0\",\"error\":{\"code\":1,\"message\":\"SESSION_AUTHENTICATION_FAILED\",\"data\":[\"root\",\"Authentication failure\"]},\"id\":1}";

const Response = union(enum) {
    ok: struct { message: []const u8 },
    not_ok: struct { code: u8, message: []const u8 },
};

fn parse_response(allocator: std.mem.Allocator, r: []const u8) !void {
    std.debug.print("== response len {d}\n", .{r.len});
    std.debug.print("== Parsing <{s}>\n", .{r});
    var it = std.http.HeaderIterator.init(r);
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "content-length")) {
            const v = try std.fmt.parseInt(usize, h.value, 10);
            std.debug.print("> {d}\n", .{v});
        }
    }

    var head: std.http.HeadParser = .{};
    const off = head.feed(r);
    std.debug.print("feed returns: {d}\n", .{off});
    std.debug.print("body: <{s}>\n", .{r[off..]});

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, r[off..], .{});
    defer parsed.deinit();
    std.debug.print("parsed: {any}\n", .{@TypeOf(parsed)});
    switch (parsed.value) {
        .object => |o| {
            std.debug.print("found an object of type {any}\n", .{@TypeOf(o)});
            for (o.keys()) |key| {
                std.debug.print("  {s}\n", .{key});
            }
        },
        else => std.debug.print("found something else", .{}),
    }
}

fn writeRpcRequest(allocator: std.mem.Allocator, method: []const u8, params: []const []const u8, id: usize) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    var w: std.json.Stringify = .{ .writer = &out.writer };

    try w.beginObject();
    try w.objectField("jsonrpc");
    try w.write("2.0");
    try w.objectField("method");
    try w.write(method);
    try w.objectField("params");
    try w.beginArray();
    for (params) |param| {
        try w.write(param);
    }
    try w.endArray();
    try w.objectField("id");
    try w.print("{}", .{id});
    try w.endObject();

    return out.toOwnedSlice();
}
