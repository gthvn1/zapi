const std = @import("std");
const net = std.Io.net;
const print = std.debug.print;

const IPADDR = "127.0.0.1";
const PORT = 6666;

const Self = @This();

conn: ?net.Stream = null,
io: std.Io,

pub fn connect(io: std.Io) !Self {
    const peer = try net.IpAddress.parseIp4(IPADDR, PORT);
    const conn = try peer.connect(io, .{ .mode = .stream });
    return .{ .conn = conn, .io = io };
}

pub fn close(self: *Self) void {
    if (self.conn) |conn| {
        conn.close(self.io);
    }
}

pub fn send(self: *Self, body: []const u8) !void {
    // We want to send:
    //❯ curl -v http://localhost/jsonrpc -d '{
    //    "jsonrpc":"2.0",
    //    "method":"session.login_with_password",
    //    "params":["root","pass","1.0","gtntest"],
    //    "id":1}'
    //
    // For testing we can run locally: nc -kl 6666

    const conn = if (self.conn) |conn|
        conn
    else
        return error.ConnectionNotInitialized;

    var wbuf: [1024]u8 = undefined;
    var w = conn.writer(self.io, &wbuf);
    try w.interface.print("POST /jsonrpc HTTP/1.1\r\n", .{});
    try w.interface.print("Host: {s}\r\n", .{IPADDR});
    try w.interface.print("User-Agent: zig/0.0.7\r\n", .{});
    try w.interface.print("Accept: */*\r\n", .{});
    try w.interface.print("Content-Length: {d}\r\n", .{body.len});
    try w.interface.print("Content-Type: application/json\r\n", .{});
    try w.interface.print("Connection: close\r\n", .{});
    try w.interface.print("\r\n", .{});
    try w.interface.print("{s}", .{body});
    try w.interface.flush();

    var rbuf: [1024]u8 = undefined;
    var r = conn.reader(self.io, &rbuf);

    var chunk: [1024]u8 = undefined;
    while (true) {
        const n = try r.interface.readSliceShort(&chunk);
        print("{s}\n", .{chunk[0..n]});
        if (n < chunk.len) break;
    }
}
