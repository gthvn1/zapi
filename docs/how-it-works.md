# How zapi works

This document follows ONE example from start to end: the XAPI message
`VM.get_name_label`. At each step it shows the real value we have at that
point. There is no abstraction: if you get lost, find the step and look at
the value.

The pipeline is:

    xenapi.json
        |  std.json + RawXapi.parse()          (src/RawXapi.zig)
        v
    RawXapi: ClassInfo / MessageInfo / MessageInfoParam
        |  emit.xapi_bindings()                (src/emit.zig)
        |    uses TypeParser.parse()           (src/TypeParser.zig)
        v
    generated/xapi.zig                         (text, formatted by std.zig.Ast)
        |  @import("xapi") in examples/basic.zig
        v
    at runtime: JSON-RPC over HTTP to XAPI     (code from src/rpc.zig)

Two programs are involved, keep them apart in your head:

- the GENERATOR (`zapi`, src/main.zig + emit.zig ...) runs at build time and
  WRITES text.
- the GENERATED CODE (generated/xapi.zig) is compiled into basic.zig and
  RUNS against a real XAPI.


## Step 1 - The JSON (xenapi.json)

xenapi.json is an array of classes. Inside the class "VM", in "messages",
there is this entry (fields we don't use are removed):

    {
      "name": "get_name_label",
      "params": [
        { "name": "session_id", "type": "session ref" },
        { "name": "self",       "type": "VM ref" }
      ],
      "result": ["string", "value of the field"]
    }

Notes:

- types are plain TEXT: "session ref", "VM ref", "string".
- "result" is an array; we only keep the first element (the type).


## Step 2 - RawXapi (src/RawXapi.zig)

`RawXapi.parse()` walks the `std.json.Value` and copies what we need into
small structs. For our message we get:

    ClassInfo {
      name     = "VM"
      fields   = [...]
      messages = [ ..., MessageInfo, ... ]
    }

    MessageInfo {
      name   = "get_name_label"
      params = [
        MessageInfoParam { name = "session_id", type = "session ref" },
        MessageInfoParam { name = "self",       type = "VM ref" },
      ]
      result = "string"
    }

Types are STILL text here. RawXapi does not understand them.

`ClassInfo.hasRef()` answers: "is VM a real object with a ref?". It looks
for a parameter whose type is "VM ref" (or "VM ref set", ...) in the VM
messages. For VM the answer is yes. 64 of the 70 classes have a ref.

You can see this step with:

    ./zig-out/bin/zapi -r xenapi.json


## Step 3 - TypeParser (src/TypeParser.zig)

`TypeParser.parse(text)` turns a type text into a small tree (`AstNode`).
The tree says WHAT the type is. It contains no Zig text and no JSON text.

For our message:

    "session ref"  ->  .{ .ref = "session" }
    "VM ref"       ->  .{ .ref = "VM" }
    "string"       ->  .string

A more nested example, "VM ref set" (used by VM.get_all):

    set
     `-- ref "VM"

How the parser reads it: look at the LAST word.

- "set" is a postfix keyword: it is a set of ... the rest, "VM ref".
- in "VM ref", the last word is "ref": it is a ref to class "VM".

Rules (in this order):

1. the whole text is a builtin (string, int, float, bool, datetime, void)
   -> leaf with no payload.
2. the last word is ref / record -> leaf holding the class name.
3. the last word is set / option -> node with ONE child: parse the rest.
4. the first word is enum -> leaf holding the enum name.
5. otherwise -> error.

Postfix is checked before prefix, so "enum foo set" gives `set -> enum "foo"`.

The tree keeps the XAPI names ("VM"). Turning "VM" into "Vm" is not the
parser's job.


## Step 4 - The emitter (src/emit.zig)

The emitter writes Zig TEXT into an in-memory buffer (the "draft"). At the
end it parses the draft with `std.zig.Ast.parse()`:

- if there are syntax errors, it logs them and fails;
- otherwise it renders the formatted code (like `zig fmt`) to stdout.

For each class it writes:

    pub const Vm = struct {
        ref: []const u8,                                   // only if hasRef()
        pub const jsonParseFromValue = rpc.OpaqueRef(Vm).jsonParseFromValue;
        ... functions ...
    };

The class name "VM" becomes "Vm" with the `ClassName` formatter
(`{f}` in print): split on '_', uppercase the first letter of each part,
lowercase the rest. "VM_group" -> "VmGroup".

For our message, the emitter does:

a) `findSelf()` finds which parameter plays the role of `self`:
   1. a parameter named "self"            -> index 1 here
   2. else the first param of type "<class> ref" (for session.logout this is
      session_id)
   3. else null (static function, like get_all)

b) the SIGNATURE: self first, then `conn`, then the other params. Each type
   is parsed (step 3) then written with `writeZigType()`:

       .string     -> []const u8
       .ref "VM"   -> Vm             (via ClassName)
       .set child  -> [] + child     ("VM ref set" -> []Vm)
       .option     -> ? + child

c) the BODY: the params array in XAPI order (NOT the signature order):

       .ref    -> name.ref
       .string -> name
       other   -> error (not supported yet)

Result, in generated/xapi.zig:

    pub fn get_name_label(
        self: Vm,
        conn: *Conn,
        session_id: Session,
    ) ![]const u8 {
        const params: [2][]const u8 = .{
            session_id.ref,
            self.ref,
        };
        const body = try rpc.writeRequest(conn.allocator, "VM.get_name_label", &params, 1);
        defer conn.allocator.free(body);
        return rpc.call(conn, []const u8, body);
    }

Note the order: in the signature `self` is first, in `params` it is second,
like in the JSON (step 1).

Because `self` is the first parameter and its type is `Vm`, the user can
write `vm.get_name_label(&conn, session)`. Zig rewrites it into
`Vm.get_name_label(vm, &conn, session)`.

The generated file also contains, before `Class`:

    const rpc = struct { ...the whole text of src/rpc.zig... };
    pub const Conn = rpc.Connection;

`rpc` is not pub: users cannot call `rpc.call` directly. `Conn` is pub.


## Step 5 - The build (build.zig)

`zig build` does, in order:

1. compile `zapi` (the generator).
2. run `zapi -e xenapi.json`, capture stdout.
3. copy that output to generated/xapi.zig (in the repo).
4. compile examples/basic.zig with `@import("xapi")` = generated/xapi.zig.

So generated/xapi.zig is always up to date, and it is the exact file a user
could copy into their project.


## Step 6 - At runtime (code from src/rpc.zig)

In basic.zig:

    const name = try vm.get_name_label(&conn, session);

Suppose `vm.ref` is "OpaqueRef:1111" and `session.ref` is "OpaqueRef:2222"
(real refs are longer UUIDs).

6a) `rpc.writeRequest()` builds the JSON body with `std.json.Stringify`:

    {"jsonrpc":"2.0","method":"VM.get_name_label",
     "params":["OpaqueRef:2222","OpaqueRef:1111"],"id":1}

6b) `rpc.call()` sends it over HTTP:

    POST /jsonrpc HTTP/1.1
    Host: 127.0.0.1
    Content-Length: <size of the body>
    Content-Type: application/json

    {"jsonrpc":"2.0","method":"VM.get_name_label",...}

6c) XAPI answers. `call()` reads the headers line by line until the empty
line, finds Content-Length, then reads exactly that many bytes:

    {"jsonrpc":"2.0","result":"Debian Bookworm 12","id":1}

6d) `Response.parseJsonRpc()` parses it into a generic `std.json.Value` and
checks for an "error" field. Here there is none, so we keep:

    result = .{ .string = "Debian Bookworm 12" }

6e) `std.json.parseFromValueLeaky(RetType, ...)` converts that Value into
the Zig type the generated function asked for. Here RetType is
`[]const u8`, so we get the string "Debian Bookworm 12" (copied into
conn.arena, so it stays valid after call() returns).

How does std.json know what to do? `RetType` is known at COMPILE time
(`comptime RetType: type`). std.json looks at the type with `@typeInfo`
and generates the right conversion:

    []const u8      expects a JSON string, copies it
    []Vm            expects a JSON array, then converts each element to Vm
    Vm              Vm has a function named jsonParseFromValue, so std.json
                    calls it (this is rpc.OpaqueRef(Vm).jsonParseFromValue):
                    it expects a JSON string and returns .{ .ref = <copy> }
    void            nothing to convert (call() returns early)

For VM.get_all (RetType = []Vm) the response is:

    {"result":["OpaqueRef:1111","OpaqueRef:3333",...]}

and std.json calls Vm.jsonParseFromValue once per string, giving a slice
of Vm, each with its own `.ref`.

Memory: everything returned lives in `conn.arena` until `conn.close()`.


## Not done yet (the next steps)

- params are `[]const u8` only, so only `string` and `X ref` parameters
  work. Plan: pass a tuple `.{ session_id, self, value }` to writeRequest
  (received as `params: anytype`). std.json.Stringify writes any Zig value
  (numbers, bools, slices ...) by looking at its type at compile time,
  exactly like 6e but in the other direction. Classes would get a
  `jsonStringify` method that writes only their `.ref` string.
- TypeParser does not handle `map` yet: "(K -> V) map", nested parens.
- `record`, `enum`, `datetime`, `map` are not rendered to Zig yet.
- only 4 messages are generated (filter in xapi_bindings).
- XAPI error code and message are lost (`error.CallFailed`).
- two odd types exist in xenapi.json: field event.snapshot has type
  "<class> record" and event.from returns "an event batch".
- some parameters are not required. The idiomatic Zig way is to use an opts
  struct at the end of the parameters. It can be `.{}`.
