Generates XAPI bindings for Zig following the approach introduced in [xapy](https://github.com/contificate/xapy/).

- Build: `zig build`
- Display XAPI classes (read from xenapi.json): `./zig-out/bin/zapi -r xenapi.json`
- Emit the code (WIP): `./zig-out/bin/zapi -e xenapi.json > /tmp/xapi.zig && zig ast-check /tmp/xapi.zig`
- Status
    1. [x] JSON Parse -> generic `std.json.Value`
    2. [x] Extract to IR ([RawXapi.zig](https://github.com/gthvn1/zapi/blob/master/src/RawXapi.zig)) -> ClassInfo/FieldInfo/MessageInfo: a domain representation that still keeps raw strings.
    3. [x] Write `src/xapi.zig` by hand to have a working basic example to understand how to wire things.
    4. [ ] Tokenize + parse type strings -> real AST, replacing the raw strings.
    5. [ ] Code generation -> walk the now-typed IR and emit Zig source (structs + sync call functions).
- The pipeline is:
    - `xenapi.json -> RawXapi (ClassInfo) -> TypeParser (Zig types) -> emitter (text) -> generated xapi.zig`

- See an example of expected usage `./examples/basic.zig`:

<!-- BEGIN_CODE [examples/basic.zig] -->
```zig
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
```
<!-- END_CODE [examples/basic.zig] -->

- If you have a running XAPI, with creds, you should see (out of date):
<!-- BEGIN_CODE [examples/basic_output] -->
```
- Windows Server 2022 (64-bit)
- Ubuntu Focal Fossa 20.04 (deprecated)
- Red Hat Enterprise Linux 9
- Red Hat Enterprise Linux 8
- Rocky Linux 9
- AlmaLinux 10
- Generic Linux UEFI
- Scientific Linux 7 (deprecated)
- Red Hat Enterprise Linux 10
- Ubuntu Jammy Jellyfish 22.04
- Oracle Linux 10
- AlmaLinux 8
- Oracle Linux 9
- CentOS Stream 9
- Red Hat Enterprise Linux 7 (deprecated)
- Rocky Linux 10
- Windows 10 (64-bit)
- Gooroom Platform 2.0
- SUSE Linux Enterprise 15 (64-bit)
- Ubuntu Noble Numbat 24.04
- Generic Linux BIOS
- Debian Buster 10 (deprecated)
- Windows 11
- SUSE Linux Enterprise Server 12 SP5 (64-bit)
- CentOS Stream 8
- Windows Server 2019 (64-bit)
- Windows Server 2016 (64-bit)
- Debian Trixie 13
- CentOS 7 (deprecated)
- Oracle Linux 7 (deprecated)
- Debian Bookworm 12
- Windows Server 2025
- AlmaLinux 9
- Rocky Linux 8
- Debian Bullseye 11
- Control domain on host: xcp-host-01
- CentOS Stream 10
- Other install media
- Oracle Linux 8
Basic done
```
<!-- END_CODE [examples/basic_output] -->

# Tips
- For testing, set up the connection using: `ssh -L 6666:localhost:80 xapi-host`
- If you don't have a host running xapi, you can see what is sent using: `nc -kl 6666`
- *Note*: I had an issue with multiline strings. Zig multiline only produces `\n`, while
          HTTP headers require `\r\n`. To see it: `nc -kl 6666 | xxd`
- To run sandbox examples live: `cd sandbox; echo mem.zig | entr -c zig run mem.zig`
