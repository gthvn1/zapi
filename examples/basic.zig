const std = @import("std");
const xapi = @import("xapi");

const IPADDR = "127.0.0.1";
const PORT = 6666;

pub const std_options: std.Options = .{
    // Use .level = .info to disable debug message
    .log_scope_levels = &.{.{ .scope = .xapirpc, .level = .debug }},
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const w = &stdout_file_writer.interface;

    const Session = xapi.Class.Session;
    const Vm = xapi.Class.Vm;

    var conn = try xapi.Conn.open(init.gpa, init.io, IPADDR, PORT);
    defer conn.close();

    const session = try Session.login_with_password(&conn, "root", "pass", "1.0", "gthvn1_test");
    defer session.logout(&conn) catch std.log.err("Failed to logout", .{});

    const vms = try Vm.get_all(&conn, session);
    for (vms) |vm| {
        const name = try vm.get_name_label(&conn, session);
        try w.print("- {s}\n", .{name});
    }

    try w.writeAll("Basic done\n");
    try w.flush();
}
