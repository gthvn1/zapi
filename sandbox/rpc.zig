const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var arena = init.arena;
    const a = arena.allocator();

    // Testing generation of RPC
    const params: [2][]const u8 = .{ "hello", "sailor" };
    const rpc = try writeRpcRequest(a, "Say", &params, 42);

    std.debug.print("JSON size: {d}\n", .{rpc.len});
    std.debug.print("{s}\n", .{rpc});

    // Testing the parsing of response
    const r1 = try parseResponse(a, login_failure_response);
    if (r1 == .not_ok) {
        std.debug.print("[OK] error checked\n", .{});
    } else {
        std.debug.print("Ooops not expected\n", .{});
    }

    const r2 = try parseResponse(a, login_success_response);
    if (r2 == .ok) {
        std.debug.print("[OK] success checked\n", .{});
    } else {
        std.debug.print("Ooops not expected\n", .{});
    }
}

const login_success_response =
    "HTTP/1.1 200 OK\r\n" ++
    "content-length: 82\r\n" ++
    "connection: close\r\n" ++
    "cache-control: no-cache, no-store\r\n" ++
    "content-type: application/json\r\n" ++
    "Access-Control-Allow-Origin: *\r\n" ++
    "Access-Control-Allow-Headers: X-Requested-With\r\n" ++
    "\r\n" ++
    "{\"jsonrpc\":\"2.0\",\"result\":\"OpaqueRef:11963daf-83d6-089d-570a-ee33e841db48\",\"id\":1}";

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
    ok: std.json.Value,
    not_ok: struct { code: i64, message: []const u8, data: std.json.Value },
};

fn getField(v: std.json.Value, key: []const u8) ?std.json.Value {
    return switch (v) {
        .object => |o| o.get(key),
        else => null,
    };
}

fn getString(v: std.json.Value, key: []const u8) ?[]const u8 {
    const field = getField(v, key) orelse return null;
    return switch (field) {
        .string, .number_string => |s| s,
        else => null,
    };
}

fn getInt(v: std.json.Value, key: []const u8) ?i64 {
    const field = getField(v, key) orelse return null;
    return switch (field) {
        .integer => |i| i,
        else => null,
    };
}

fn parseResponse(allocator: std.mem.Allocator, r: []const u8) !Response {
    std.debug.print("== Response len {d}\n", .{r.len});
    std.debug.print("== Response start ==\n{s}\n== Response end ==\n", .{r});
    var it = std.http.HeaderIterator.init(r);
    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "content-length")) {
            const v = try std.fmt.parseInt(usize, h.value, 10);
            std.debug.print("> {d}\n", .{v});
        }
    }

    var head: std.http.HeadParser = .{};
    const off = head.feed(r);
    std.debug.print("== Bytes consumed by header: {d}\n", .{off});
    // We can now find the body
    const body = r[off..];
    std.debug.print("== body start ==\n{s}\n== body end==\n", .{body});

    const parsed: std.json.Value = try std.json.parseFromSliceLeaky(
        std.json.Value,
        allocator,
        body,
        .{},
    );

    // Check if it is an error. Not that JSON-RPC 1.0 allows "
    // error: null".
    if (getField(parsed, "error")) |e| {
        if (e != .null) {
            const code = getInt(e, "code") orelse return error.CodeMissing;
            const msg = getString(e, "message") orelse return error.MsgMissing;
            const data: std.json.Value = getField(e, "data") orelse .null;
            return .{ .not_ok = .{
                .code = code,
                .message = msg,
                .data = data,
            } };
        }
    }

    if (getField(parsed, "result")) |result| {
        return .{
            .ok = result,
        };
    }

    return error.InvalidResponse;
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
