const std = @import("std");
const net = std.Io.net;

const Response = union(enum) {
    ok: std.json.Value,
    not_ok: struct { code: i64, message: []const u8, data: std.json.Value },

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

    // Allocations made during this operation are not carefully tracked and may
    // not be possible to individually clean up. It is recommended to use a
    // std.heap.ArenaAllocator
    fn parseJsonRpc(allocator: std.mem.Allocator, rpc: []const u8) !Response {
        const parsed: std.json.Value = try std.json.parseFromSliceLeaky(
            std.json.Value,
            allocator,
            rpc,
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
};

pub const Conn = struct {
    stream: ?net.Stream = null,
    allocator: std.mem.Allocator, // This can by use to create local arena for leaky allocation
    arena: std.heap.ArenaAllocator,
    io: std.Io,
    hostname: []const u8,

    pub fn open(allocator: std.mem.Allocator, io: std.Io, hostname: []const u8, port: u16) !Conn {
        const peer = try net.IpAddress.parseIp4(hostname, port);
        const conn = try peer.connect(io, .{ .mode = .stream });
        return .{
            .stream = conn,
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .io = io,
            .hostname = hostname,
        };
    }

    pub fn close(self: *Conn) void {
        self.arena.deinit();
        if (self.stream) |stream| {
            stream.close(self.io);
        }
    }
};

// We don't want call to be public (accessible to the end user). As Conn is public we don't
// put it as a method of Conn. But it is public for the generated xapi.zig file.
pub fn call(conn: *Conn, comptime RetType: type, body: []u8) !RetType {
    // We want to send:
    //❯ curl -v http://localhost/jsonrpc -d '{
    //    "jsonrpc":"2.0",
    //    "method":"session.login_with_password",
    //    "params":["root","pass","1.0","gtntest"],
    //    "id":1}'
    //
    // For testing we can run locally: nc -kl 6666
    const s = conn.stream orelse return error.ConnectionNotInitialized;

    // First the writer, send the JSON-RPC CALL
    var wbuf: [1024]u8 = undefined;
    var w = s.writer(conn.io, &wbuf);

    // Don't use multiline, it does not produce correct escape sequence.
    const headers_fmt =
        "POST /jsonrpc HTTP/1.1\r\n" ++
        "Host: {s}\r\n" ++
        "User-Agent: zig/0.0.7\r\n" ++
        "Accept: */*\r\n" ++
        "Content-Length: {d}\r\n" ++
        "Content-Type: application/json\r\n" ++
        "\r\n";

    try w.interface.print(headers_fmt, .{ conn.hostname, body.len });
    try w.interface.writeAll(body);
    try w.interface.flush();

    // Second, read the response now. We first read the header, extract the
    // content length and read the body.
    var rbuf: [1024]u8 = undefined;
    var r = s.reader(conn.io, &rbuf);

    var resp_header: std.Io.Writer.Allocating = .init(conn.allocator);
    defer resp_header.deinit();

    while (true) {
        const bytes_read = try r.interface.streamDelimiter(&resp_header.writer, '\n');
        // write the delimiter and remove it from reader
        _ = try resp_header.writer.write("\n");
        r.interface.toss(1);
        // Check if we are at the end of the header that is "\r\n";
        if (bytes_read == 1) break;
    }
    std.debug.print("= Header begin =\n{s}\n= Header end =\n", .{resp_header.written()});

    // We should have the header now, let's check the content-length
    var it = std.http.HeaderIterator.init(resp_header.written());
    var content_length: ?usize = null;

    while (it.next()) |h| {
        if (std.ascii.eqlIgnoreCase(h.name, "content-length")) {
            content_length = try std.fmt.parseInt(usize, h.value, 10);
            break;
        }
    }
    const len = content_length orelse return error.ContentLentghNotFound;

    // And now we read the body
    var resp_content: std.Io.Writer.Allocating = .init(conn.allocator);
    defer resp_content.deinit();

    try r.interface.streamExact(&resp_content.writer, len);

    std.debug.print("= Body begin =\n{s}\n= Body end =\n", .{resp_content.written()});

    // TODO: extract information from response if type is not void

    var local_arena = std.heap.ArenaAllocator.init(conn.allocator);
    defer local_arena.deinit();
    const response = try Response.parseJsonRpc(local_arena.allocator(), resp_content.written());
    const result = switch (response) {
        .ok => |v| v,
        .not_ok => |e| {
            std.debug.print("Got error {d}:{s}\n", .{ e.code, e.message });
            return error.CallFailed;
        },
    };

    if (RetType == void) return;
    // TODO: implement jsonParseFromValue for RetType
    // See https://ziglang.org/documentation/master/std/#std.json.static.innerParseFromValue
    return try std.json.parseFromValueLeaky(RetType, conn.arena.allocator(), result, .{});
}

pub fn writeRequest(gpa: std.mem.Allocator, method: []const u8, params: []const []const u8, id: usize) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(gpa);
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
