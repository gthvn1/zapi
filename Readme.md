Generates bindings for Zig following the approach introduced in [xapy](https://github.com/contificate/xapy/).

- Build: `zig build`
- Run: `./zig-out/bin/zapi xapi.json`

- Status
    1. [x] JSON Parse -> generic `std.json.Value`
    2. [x] Extract to IR ([raw_xapi.zig](https://github.com/gthvn1/zapi/blob/master/src/raw_xapi.zig)) -> ClassInfo/FieldInfo/MessageInfo that is domain representation but keep raw strings.
    3. [ ] Tokenize + parse type strings -> real AST for every type field, replacing the raw strings.
    4. [ ] Code generation -> walk the now typed IR and emit Zig source (structs + sync call functions).

- See an example of expected usage: `./examples/basic.zig`
