Generates bindings for Zig following the approach introduced in https://github.com/contificate/xapy/.

- Build: `zig build`
- Run: `./zig-out/bin/zapi xapi.json`

- Status
  - Four stages:
    1. [x] JSON Parse -> generic `std.json.Value`
    2. [x] Extract to IR ([raw_xapi.zig](https://github.com/gthvn1/zapi/blob/master/src/raw_xapi.zig)) -> ClassInfo/FieldInfo/MessageInfo that is domain representation but keep raw strings.
    3. [ ] Tokenize + parse type strings -> real AST for every type field, replacing the raw strings.
    4. [ ] Code generation -> walk the now typed IR and emit Zig source (structs + sync call functions).

- So we want to be able to write something like:
```zig
const Xapi = @import("generated_xapi.zig");
const Session = Xapi.Session;
const Vm = Xapi.Vm;

var conn = try Session.login_with_password("user", "pass");
const vms = try Vm.get_all(&conn);
for (vms) |vm| {
  const name = try vm.get_name_label(&conn);
  std.debug.print("- {s}, .{name}");
}

Session.logout(&conn);

```
- At the end we expect to send a JSON-RPC:
```json
{
  "jsonrpc": "2.0",
  "method": "session.login_with_password",
  "params": [
    "root",
    "yourpassword",
    "1.0",
    "test"
  ],
  "id": 1
}
```
And we are expecting a response like:
```json
{
  "jsonrpc": "2.0",
  "result": "OpaqueRef:eaa915d1-49e7-2144-5085-53a02255794e",
  "id": 1
}
```
