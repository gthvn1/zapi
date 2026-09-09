Generates bindings for Zig following the approach introduced in https://github.com/contificate/xapy/.

- build: `zig build`
- run: `./zig-out/bin/zapi xapi.json`

Four stages:
1. [x] JSON Parse -> generic `std.json.Value`
2. [x] Extract to IR ([raw_xapi.zig](https://github.com/gthvn1/zapi/blob/master/src/raw_xapi.zig)) -> ClassInfo/FieldInfo/MessageInfo that is domain representation but keep raw strings.
3. [ ] Tokenize + parse type strings -> real AST for every type field, replacing the raw strings.
4. [ ] Code generation -> walk the now typed IR and emit Zig source (structs + sync call functions).

At the end we expect to send a JSON-RPC:
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
