//
// /!\ THE FILE WILL BE GENERATED. FOR TESTING PURPOSE WE DO IT BY HAND /!\
//
const std = @import("std");
const net = std.Io.net;

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
        const s = self.stream orelse return error.ConnectionNotInitialized;

        // First the writer, send the JSON-RPC CALL
        var wbuf: [1024]u8 = undefined;
        var w = s.writer(self.io, &wbuf);

        // Don't use multiline, it does not produce correct escape sequence.
        const headers_fmt =
            "POST /jsonrpc HTTP/1.1\r\n" ++
            "Host: {s}\r\n" ++
            "User-Agent: zig/0.0.7\r\n" ++
            "Accept: */*\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Content-Type: application/json\r\n" ++
            "\r\n";

        try w.interface.print(headers_fmt, .{ self.hostname, body.len });
        try w.interface.writeAll(body);
        try w.interface.flush();

        // Second, read the response now. We first read the header, extract the
        // content length and read the body.
        var rbuf: [1024]u8 = undefined;
        var r = s.reader(self.io, &rbuf);

        var resp_header: std.Io.Writer.Allocating = .init(self.allocator);
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
        var resp_content: std.Io.Writer.Allocating = .init(self.allocator);
        defer resp_content.deinit();

        try r.interface.streamExact(&resp_content.writer, len);

        std.debug.print("= Body begin =\n{s}\n= Body end =\n", .{resp_content.written()});
        // TODO: extract information from body

        // TODO: Ugly hack to be able to compile and run basic.zig
        if (RetType == void) return;
        if (RetType == Class.SessionRef) return .{ .ref = "OpaqueRef:stub" };
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
