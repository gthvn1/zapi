//
// /!\ THE FILE WILL BE GENERATED. FOR TESTING PURPOSE WE DO IT BY HAND /!\
//

// When the file will be generated we will probably do:
//
// const rpc = struct {
//    ... write the contents of rpc.zig
// }
//
// Note: the generator may use @embedFile to get the tewt of rpc.zig as a string
// and writes it into the output.
//
// So we need to take care that std is not declared twice. To achieve that we put
// const std inside Class.
const rpc = @import("rpc.zig");
pub const Conn = rpc.Connection;

pub const Class = struct {
    const std = @import("std");

    fn OpaqueRef(comptime T: type) type {
        return struct {
            pub fn jsonParseFromValue(allocator: std.mem.Allocator, src: std.json.Value, opts: std.json.ParseOptions) !T {
                _ = opts;
                // We are expecting "OpaqueRef:6206e66c-9cd1-561c-1519-6ce38cd41dfe"
                // src has been allocated from local arena, so we need to dupe
                switch (src) {
                    .string => |s| {
                        std.debug.print("custom: {s}\n", .{s});
                        return .{ .ref = try allocator.dupe(u8, s) };
                    },
                    else => return std.json.ParseFromValueError.UnexpectedToken,
                }
            }
        };
    }

    // From raw parsing we see that:
    // ClassInfo: session
    //   ...
    // Messages:
    //   ...
    //   login_with_password (uname: string, pwd: string, version: string, originator: string) -> session ref
    //   ...
    //   logout (session_id: session ref) -> void
    pub const Session = struct {
        ref: []const u8,
        pub const jsonParseFromValue = OpaqueRef(Session).jsonParseFromValue;

        pub fn login_with_password(
            conn: *Conn,
            uname: []const u8,
            pwd: []const u8,
            version: []const u8,
            originator: []const u8,
        ) !Session {
            const params: [4][]const u8 = .{ uname, pwd, version, originator };
            const body = try rpc.writeRequest(conn.allocator, "session.login_with_password", &params, 1);
            defer conn.allocator.free(body);
            return rpc.call(conn, Session, body);
        }

        // TODO: we can probably detect that a parameter is the class
        // and so put it first before the conn. To be checked but it
        // looks like the API already named "self" the parameter that
        // is the class... so we can rely on that probably. We can probably
        // also consider session_id as a special case since it is still needed.
        // So put self first, otherwise session_id, otherwise conn (something like
        // that)...
        pub fn logout(session_id: Session, conn: *Conn) !void {
            const params: [1][]const u8 = .{session_id.ref};
            const body = try rpc.writeRequest(conn.allocator, "session.logout", &params, 1);
            defer conn.allocator.free(body);
            return rpc.call(conn, void, body);
        }
    };

    // From raw parsing we see that:
    // ClassInfo: VM
    //   ...
    // Messages:
    //   ...
    //   get_all (session_id: sesssion ref) -> VM ref set
    //   ...
    //   get_name_label (session_id: session ref, self: VM ref) -> string
    pub const Vm = struct {
        ref: []const u8,
        pub const jsonParseFromValue = OpaqueRef(Vm).jsonParseFromValue;

        pub fn get_all(conn: *Conn, session_id: Session) ![]Vm {
            const params: [1][]const u8 = .{session_id.ref};
            const body = try rpc.writeRequest(conn.allocator, "VM.get_all", &params, 1);
            defer conn.allocator.free(body);
            return rpc.call(conn, []Vm, body);
        }

        // NOTE: for generator, if we have self in the list of parameter it can
        // come first.
        pub fn get_name_label(self: Vm, conn: *Conn, session_id: Session) ![]const u8 {
            const params: [2][]const u8 = .{ session_id.ref, self.ref };
            const body = try rpc.writeRequest(conn.allocator, "VM.get_name_label", &params, 1);
            defer conn.allocator.free(body);
            return rpc.call(conn, []const u8, body);
        }
    };
};
