const std = @import("std");
const xapi = @import("xapi");

// Variables can be overwrite by setting XAPI_<variable_name> in your
// environment.
const USER = "user";
const PASS = "pass";
const HOST = "127.0.0.1";
const PORT = "6666";

pub const std_options: std.Options = .{
    // Use .level = .info to disable debug message
    .log_scope_levels = &.{.{ .scope = .xapirpc, .level = .debug }},
};

pub fn main(init: std.process.Init) !void {
    // Checking environment variables
    const env = init.environ_map;
    const user = env.get("XAPI_USER") orelse USER;
    const pass = env.get("XAPI_PASS") orelse PASS;
    const host = env.get("XAPI_HOST") orelse HOST;
    const port_s = env.get("XAPI_PORT") orelse PORT;
    const port = try std.fmt.parseInt(u16, port_s, 10);

    // Setup stdout writer
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const w = &stdout_file_writer.interface;

    // Let's call XAPI API !!!
    const Session = xapi.Class.Session;
    const Vm = xapi.Class.Vm;

    var conn = try xapi.Conn.open(init.gpa, init.io, host, port);
    defer conn.close();

    const session = try Session.login_with_password(&conn, user, pass, "1.0", "gthvn1_test");
    defer session.logout(&conn) catch std.log.err("Failed to logout", .{});

    const vms = try Vm.get_all(&conn, session);
    for (vms) |vm| {
        const name = try vm.get_name_label(&conn, session);
        try w.print("- {s}\n", .{name});
    }

    try w.writeAll("Basic done\n");
    try w.flush();
}
