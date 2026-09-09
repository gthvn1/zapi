const generated = @import("generated");
const Session = generated.Session;

pub fn main() void {
    var session = Session.login_with_password("root", "pass", "1.0", "test");
    defer session.logout();
}
