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

    fn call(self: *const Conn, comptime RetType: type, body: []u8) !RetType {
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

        return undefined;
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
    fn OpaqueRef(comptime classname: []const u8) type {
        return struct {
            ref: []const u8,
            pub const class_name = classname;
        };
    }

    pub const SessionRef = OpaqueRef("session");
    pub const VmRef = OpaqueRef("VM");

    pub const Session = struct {
        pub fn login_with_password(
            conn: *const Conn,
            uname: []const u8,
            pwd: []const u8,
            version: []const u8,
            originator: []const u8,
        ) !SessionRef {
            const params: [4][]const u8 = .{ uname, pwd, version, originator };
            const body = try writeRpcRequest(conn.allocator, "session.login_with_password", &params, 1);
            defer conn.allocator.free(body);
            return conn.call(SessionRef, body);
        }

        // TODO: we can probably detect that a parameter is the class
        // and so put it first before the conn. To be checked but it
        // looks like the API already named "self" the parameter that
        // is the class... so we can rely on that probably.
        pub fn logout(conn: *Conn, session: SessionRef) !void {
            const params: [1][]const u8 = .{session.ref};
            const body = try writeRpcRequest(conn.allocator, "session.logout", &params, 1);
            defer conn.allocator.free(body);
            try conn.call(void, body);
        }
    };

    pub const Vm = struct {

        // TODO: fake VM ref set with array of VM for now
        pub fn get_all(conn: *Conn, session: SessionRef) ![]*Vm {
            // TODO: call RPC
            _ = conn;
            _ = session;
            return &[_]*Vm{};
        }

        pub fn get_name_label(self: *Vm, conn: *Conn, session: SessionRef) []const u8 {
            // TODO: call RPC
            _ = self;
            _ = conn;
            _ = session;
            return "todo";
        }
    };
};
