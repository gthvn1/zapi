//
// /!\ THE FILE WILL BE GENERATED. FOR TESTING PURPOSE WE DO IT BY HAND /!\
//
const std = @import("std");
const net = std.Io.net;
const print = std.debug.print;

pub const Conn = struct {
    stream: ?net.Stream = null,
    io: std.Io,
    hostname: []const u8,

    pub fn open(io: std.Io, hostname: []const u8, port: u16) !Conn {
        const peer = try net.IpAddress.parseIp4(hostname, port);
        const conn = try peer.connect(io, .{ .mode = .stream });
        return .{ .stream = conn, .io = io, .hostname = hostname };
    }

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

// TODO: This part will be all generated classes.
pub const Class = struct {
    pub const Session = struct {
        pub fn login_with_password(
            conn: *const Conn,
            uname: []const u8,
            pwd: []const u8,
            version: []const u8,
            originator: []const u8,
        ) !Session {
            _ = uname;
            _ = pwd;
            _ = version;
            _ = originator;
            // TODO: construct the body with parameters
            const body =
                \\{
                \\  "jsonrpc":"2.0",
                \\  "method":"session.login_with_password",
                \\  "params":["root","pass","1.0","gtntest"],
                \\  "id":1
                \\}
            ;
            try conn.call(body);

            // TODO: call will return the result of the call, we
            // need to keep the return value that is the opaqueref
            return .{};
        }

        // TODO: we can probably detect that a parameter is the class
        // and so put it first before the conn. To be checked but it
        // looks like the API already named "self" the parameter that
        // is the class... so we can rely on that probably.
        pub fn logout(self: *Session, conn: *Conn) !void {
            // TODO: self will probably hold the OpaqueRef
            _ = self;
            const body =
                \\{
                \\  "jsonrpc":"2.0",
                \\  "method":"session.logout",
                \\  "params":[???],
                \\  "id":1
                \\}
            ;
            try conn.call(body);
        }
    };

    pub const Vm = struct {
        // TODO: fake VM ref set with array of VM for now
        pub fn get_all(conn: *Conn, session_id: *Session) ![]*Vm {
            // TODO: call RPC
            _ = conn;
            _ = session_id;
            return &[_]*Vm{};
        }

        pub fn get_name_label(self: *Vm, conn: *Conn, session_id: *Session) []const u8 {
            // TODO: call RPC
            _ = self;
            _ = conn;
            _ = session_id;
            return "todo";
        }
    };
};
