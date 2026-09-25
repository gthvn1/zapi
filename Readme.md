Generates bindings for Zig following the approach introduced in [xapy](https://github.com/contificate/xapy/).

- Build: `zig build`
- Run: `./zig-out/bin/zapi xapi.json`
- Status
    1. [x] JSON Parse -> generic `std.json.Value`
    2. [x] Extract to IR ([raw_xapi.zig](https://github.com/gthvn1/zapi/blob/master/src/raw_xapi.zig)) -> ClassInfo/FieldInfo/MessageInfo: a domain representation that still keeps raw strings.
    3. [x] Write `src/xapi.zig` by hand to have a working basic example that works and understand how to wire things.
    4. [ ] Tokenize + parse type strings -> real AST for every type field, replacing the raw strings.
    5. [ ] Code generation -> walk the now-typed IR and emit Zig source (structs + sync call functions).
- See an example of expected usage `./examples/basic.zig`:

<!-- BEGIN_CODE examples/basic.zig -->
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
    defer session.logout(&conn) catch std.debug.print("Failed to logout\n", .{});

    const vms = try Vm.get_all(&conn, session);
    for (vms) |vm| {
        const name = try vm.get_name_label(&conn, session);
        std.debug.print("- {s}\n", .{name});
    }

    std.debug.print("Basic done\n", .{});
}
```
<!-- END_CODE examples/basic.zig -->

- If you have a running XAPI, with creds, you should see:
```bash
❯ ./zig-out/bin/basic
= Header begin =
HTTP/1.1 200 OK
content-length: 82
connection: keep-alive
cache-control: no-cache, no-store
content-type: application/json
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: X-Requested-With


= Header end =
= Body begin =
{"jsonrpc":"2.0","result":"OpaqueRef:74f6c79a-667f-1d96-8db5-dd9d7f61798c","id":1}
= Body end =
custom: OpaqueRef:74f6c79a-667f-1d96-8db5-dd9d7f61798c
Basic done
= Header begin =
HTTP/1.1 200 OK
content-length: 36
connection: keep-alive
cache-control: no-cache, no-store
content-type: application/json
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: X-Requested-With


= Header end =
= Body begin =
{"jsonrpc":"2.0","result":"","id":1}
= Body end =
```

# Tips
- For testing, set up the connection using: `ssh -L 6666:<xapi-host>:80 xapi-host`
- If you don't have a host running xapi, you can see what is sent using: `nc -kl 6666`
- *Note*: I had an issue with `\r\n` line endings when using multiline strings.
          To see it: `nc -kl 6666 | xxd`
- To run sandbox examples live: `cd sandbox; echo mem.zig | entr -c zig run mem.zig`
