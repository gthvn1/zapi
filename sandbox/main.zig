const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const params: [2][]const u8 = .{ "hello", "sailor" };
    const body = try writeRpcRequest(init.gpa, "Say", &params, 42);
    defer init.gpa.free(body);

    std.debug.print("JSON size: {d}\n", .{body.len});
    std.debug.print("{s}\n", .{body});
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
