Generates bindings for Zig following the approach introduced in [xapy](https://github.com/contificate/xapy/).

- Build: `zig build`
- Run: `./zig-out/bin/zapi xapi.json`

- Status
    1. [x] JSON Parse -> generic `std.json.Value`
    2. [x] Extract to IR ([raw_xapi.zig](https://github.com/gthvn1/zapi/blob/master/src/raw_xapi.zig)) -> ClassInfo/FieldInfo/MessageInfo that is domain representation but keep raw strings.
    3. [ ] Tokenize + parse type strings -> real AST for every type field, replacing the raw strings.
    4. [ ] Code generation -> walk the now typed IR and emit Zig source (structs + sync call functions).

- See an example of expected usage: `./examples/basic.zig`
```zig
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

```
