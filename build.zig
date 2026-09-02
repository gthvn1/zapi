const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "zapi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
        }),
    });

    // exe is the artifact of the compilation, we need to add a relation with install step.
    b.installArtifact(exe);

    // We can now do: zig build --watch --summary all
    // and run it: ./zig-out/bin/zapi
}
