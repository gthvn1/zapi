//
// /!\ THE FILE WILL BE GENERATED. FOR TESTING PURPOSE WE DO IT BY HAND /!\
//
const std = @import("std");
const net = std.Io.net;
const print = std.debug.print;

pub const Conn = struct {
    stream: ?net.Stream = null,
    allocator: std.mem.Allocator,
    io: std.Io,
    hostname: []const u8,

    pub fn open(allocator: std.mem.Allocator, io: std.Io, hostname: []const u8, port: u16) !Conn {
        const peer = try net.IpAddress.parseIp4(hostname, port);
        const conn = try peer.connect(io, .{ .mode = .stream });
        return .{ .stream = conn, .allocator = allocator, .io = io, .hostname = hostname };
    }

    pub fn close(self: *Conn) void {
        if (self.stream) |stream| {
            stream.close(self.io);
        }
    }

    fn call(self: *const Conn, body: []u8) !void {
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

        // Don't use multiline, it does not produce correct escape sequence.
        // TODO: Remove connection close, read the content lenght in the anwser
        // and read this exact number of bytes. Connection close is only for testing.
        // We want to keep the connection open during the session...
        const headers_fmt =
            "POST /jsonrpc HTTP/1.1\r\n" ++
            "Host: {s}\r\n" ++
            "User-Agent: zig/0.0.7\r\n" ++
            "Accept: */*\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Content-Type: application/json\r\n" ++
            "Connection: close\r\n" ++
            "\r\n";

        try w.interface.print(headers_fmt, .{ self.hostname, body.len });
        try w.interface.writeAll(body);
        try w.interface.flush();

        // TODO: See the todo above, here we just read everything. Next we need to
        // extract the content length to read the correct number of bytes. And be
        // able to read more than one response...
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
fn writeRpcRequest(gpa: std.mem.Allocator, method: []const u8, params: []const []const u8, id: usize) ![]u8 {
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

pub const Class = struct {
    pub const Session = struct {
        // TODO: Not sure at all about this. Probably need to be returned by login.
        // It should probably be part of the connection. But it means a connection
        // is related to a session. So maybe in conn we need to track an array of
        // sessions opened durint the same conn and so we lookup to check that session
        // passed as parameter are valid. Something like that...
        session: []const u8 = "OpaqueRef(TODO)",

        pub fn login_with_password(
            conn: *const Conn,
            uname: []const u8,
            pwd: []const u8,
            version: []const u8,
            originator: []const u8,
        ) !Session {
            const params: [4][]const u8 = .{ uname, pwd, version, originator };
            const body = try writeRpcRequest(conn.allocator, "session.login_with_password", &params, 1);
            defer conn.allocator.free(body);
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
            const params: [1][]const u8 = .{self.session};
            const body = try writeRpcRequest(conn.allocator, "session.logout", &params, 1);
            defer conn.allocator.free(body);
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
