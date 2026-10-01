const std = @import("std");
const json = std.json;
const Io = std.Io;

const RawXapi = @import("RawXapi.zig");
const emit = @import("emit.zig");

const Args = union(enum) {
    const usage =
        \\Usage: zapi [OPTIONS] XAPI_JSON
        \\
        \\Generate Zig bindings from a XAPI description.
        \\
        \\Arguments:
        \\  XAPI_JSON    Path to the XAPI description (e.g. xenapi.json)
        \\
        \\Options:
        \\  -e, --emit   Emit the Zig bindings on stdout
        \\  -r, --raw    Dump the parsed representation
        \\  -h, --help   Show this help and exit
        \\
    ;

    const Mode = enum {
        emit,
        raw,
    };

    const Run = struct {
        mode: ?Mode,
        file_name: []const u8,
    };

    help: void,
    run: Run,

    fn fromString(arg: [:0]const u8) !?Mode {
        if (std.mem.eql(u8, "--emit", arg) or (std.mem.eql(u8, "-e", arg))) return .emit;
        if (std.mem.eql(u8, "--raw", arg) or (std.mem.eql(u8, "-r", arg))) return .raw;
        if (std.mem.startsWith(u8, arg, "-")) return error.UnknownFlag;
        return null;
    }

    pub fn parse(args: []const [:0]const u8) !Args {
        var mode: ?Mode = null;
        var fname: ?[:0]const u8 = null;

        for (args) |arg| {
            // Return help as soon as it is detected.
            if (std.mem.eql(u8, "--help", arg) or (std.mem.eql(u8, "-h", arg))) return .help;

            if (try fromString(arg)) |m| switch (m) {
                .emit, .raw => {
                    if (mode != null) return error.ModeSetMultipleTimes;
                    mode = m;
                },
            } else {
                if (fname != null) return error.FileNameAlreadySet;
                fname = arg;
            }
        }

        const file_name = fname orelse return error.FileNameIsMissing;
        return .{
            .run = .{
                .mode = mode,
                .file_name = file_name,
            },
        };
    }
};

pub fn main(init: std.process.Init) !void {
    // We will need a writer
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    // We will need an allocator as well
    const gpa = init.gpa;

    // Parse the arguments
    const args_slice = try init.minimal.args.toSlice(init.arena.allocator());
    const args = try Args.parse(args_slice[1..]);

    blk: switch (args) {
        .help => try stdout_writer.writeAll(Args.usage),
        .run => |r| {
            const mode = r.mode orelse {
                try stdout_writer.writeAll("No mode selected, nothing to do.\n");
                break :blk;
            };

            // Read the file
            const contents = try std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), io, r.file_name, gpa, Io.Limit.unlimited);
            defer gpa.free(contents);

            // 1. Parse the json.
            const parsed = try json.parseFromSlice(std.json.Value, gpa, contents, .{});
            defer parsed.deinit();

            // 2. Extract parsed value into an intermediate representation.
            var rapi = RawXapi.init(gpa);
            defer rapi.deinit();

            try rapi.parse(parsed.value);
            // After parse() we have classes, messages and types available)

            switch (mode) {
                .emit => {
                    // TODO: we need to call the emitter. The raw API will be passed to it and it will
                    //       use the TypeParser.
                    try emit.xapi_bindings(gpa, stdout_writer, &rapi);
                },
                .raw => try rapi.dump(stdout_writer),
            }
        },
    }

    try stdout_writer.flush();
}
