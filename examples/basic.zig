const std = @import("std");
const xapi = @import("xapi");

const IPADDR = "127.0.0.1";
const PORT = 6666;

pub fn main(init: std.process.Init) !void {
    var conn = try xapi.connect(init.io, IPADDR, PORT);
    defer conn.close();

    const Session = xapi.Class.Session;
    var session = try Session.login_with_password(&conn, "root", "pass", "1.0", "test");
    defer session.logout(&conn) catch std.debug.print("Failed to logout", .{});
}
