const std = @import("std");
const xapi = @import("xapi");

const IPADDR = "127.0.0.1";
const PORT = 6666;

pub fn main(init: std.process.Init) !void {
    const Session = xapi.Class.Session;
    const Vm = xapi.Class.Vm;

    var conn = try xapi.Conn.open(init.io, IPADDR, PORT);
    defer conn.close();

    var session = try Session.login_with_password(&conn, "root", "pass", "1.0", "test");
    defer session.logout(&conn) catch std.debug.print("Failed to logout", .{});

    const vms = try Vm.get_all(&conn, &session);
    for (vms) |vm| {
        const name = vm.get_name_label(&conn, &session);
        std.debug.print("- {s}\n", .{name});
    }
}
