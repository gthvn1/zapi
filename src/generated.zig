// Currently it is hand made
pub const Session = struct {
    pub fn login_with_password(
        uname: []const u8,
        pwd: []const u8,
        version: []const u8,
        originator: []const u8,
    ) Session {
        // TODO
        _ = uname;
        _ = pwd;
        _ = version;
        _ = originator;

        return .{};
    }

    pub fn logout(self: *Session) void {
        _ = self;
    }
};
