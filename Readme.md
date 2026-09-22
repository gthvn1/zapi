Generates bindings for Zig following the approach introduced in [xapy](https://github.com/contificate/xapy/).

- Build: `zig build`
- Run: `./zig-out/bin/zapi xapi.json`

- Status
    1. [x] JSON Parse -> generic `std.json.Value`
    2. [x] Extract to IR ([raw_xapi.zig](https://github.com/gthvn1/zapi/blob/master/src/raw_xapi.zig)) -> ClassInfo/FieldInfo/MessageInfo: a domain representation that still keeps raw strings.
    3. [ ] Tokenize + parse type strings -> real AST for every type field, replacing the raw strings.
    4. [ ] Code generation -> walk the now-typed IR and emit Zig source (structs + sync call functions).

- See an example of expected usage: `./examples/basic.zig`
```zig
const std = @import("std");
const xapi = @import("xapi");

const IPADDR = "127.0.0.1";
const PORT = 6666;

pub fn main(init: std.process.Init) !void {
    const Session = xapi.Class.Session;
    const Vm = xapi.Class.Vm;

    var conn = try xapi.Conn.open(init.gpa, init.io, IPADDR, PORT);
    defer conn.close();

    const session = try Session.login_with_password(&conn, "root", "pass", "1.0", "gthvn1_test");
    defer Session.logout(&conn, session) catch std.debug.print("Failed to logout\n", .{});

    const vms = try Vm.get_all(&conn, session);
    for (vms) |vm| {
        const name = try vm.get_name_label(&conn, session);
        std.debug.print("- {s}\n", .{name});
    }

    std.debug.print("Basic done\n", .{});
}
```
# Tips
- For testing, set up the connection using: `ssh -L 6666:<xapi-host>:80 xapi-host`
- If you don't have a host running xapi, you can see what is sent using: `nc -kl 6666`
- *Note*: I had an issue with `\r\n` line endings when using multiline strings.
          To see it: `nc -kl 6666 | xxd`
- To run sandbox examples live: `cd sandbox; echo mem.zig | entr -c zig run mem.zig`
