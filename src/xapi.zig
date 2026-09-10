// /!\ THE FILE WILL BE GENERATED. FOR TESTING PURPOSE WE DO IT BY HAND /!\
const std = @import("std");
const net = std.Io.net;
const print = std.debug.print;

pub const Conn = struct {
    stream: ?net.Stream = null,
    io: std.Io,
    hostname: []const u8,

    pub fn close(self: *Conn) void {
        if (self.stream) |stream| {
            stream.close(self.io);
        }
    }

    fn call(self: *const Conn, body: []const u8) !void {
        // We want to send:
        //❯ curl -v http://localhost/jsonrpc -d '{
        //    "jsonrpc":"2.0",
        //    "method":"session.login_with_password",
        //    "params":["root","pass","1.0","gtntest"],
        //    "id":1}'
        //
        // For testing we can run locally: nc -kl 6666
        const s = if (self.stream) |s|
            s
        else
            return error.ConnectionNotInitialized;

        var wbuf: [1024]u8 = undefined;
        var w = s.writer(self.io, &wbuf);
        try w.interface.print("POST /jsonrpc HTTP/1.1\r\n", .{});
        try w.interface.print("Host: {s}\r\n", .{self.hostname});
        try w.interface.print("User-Agent: zig/0.0.7\r\n", .{});
        try w.interface.print("Accept: */*\r\n", .{});
        try w.interface.print("Content-Length: {d}\r\n", .{body.len});
        try w.interface.print("Content-Type: application/json\r\n", .{});
        try w.interface.print("Connection: close\r\n", .{});
        try w.interface.print("\r\n", .{});
        try w.interface.print("{s}", .{body});
        try w.interface.flush();

        var rbuf: [1024]u8 = undefined;
        var r = s.reader(self.io, &rbuf);

        var chunk: [1024]u8 = undefined;
        while (true) {
            const n = try r.interface.readSliceShort(&chunk);
            print("{s}\n", .{chunk[0..n]});
            if (n < chunk.len) break;
        }
    }
};

pub fn connect(io: std.Io, hostname: []const u8, port: u16) !Conn {
    const peer = try net.IpAddress.parseIp4(hostname, port);
    const conn = try peer.connect(io, .{ .mode = .stream });
    return .{ .stream = conn, .io = io, .hostname = hostname };
}

// TODO: This part will be all generated classes.
pub const Class = struct {
    // TODO: we probably want to avoid failing... but how?
    pub const Session = struct {
        pub fn login_with_password(
            conn: Conn,
            uname: []const u8,
            pwd: []const u8,
            version: []const u8,
            originator: []const u8,
        ) !Session {
            _ = uname;
            _ = pwd;
            _ = version;
            _ = originator;
            const body =
                \\{
                \\  "jsonrpc":"2.0",
                \\  "method":"session.login_with_password",
                \\  "params":["root","pass","1.0","gtntest"],
                \\  "id":1
                \\}
            ;
            try conn.call(body);

            return .{};
        }

        pub fn logout(conn: Conn, session: *Session) void {
            _ = conn;
            _ = session;
        }
    };
};
