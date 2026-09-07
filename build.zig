const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zapi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // exe is the artifact of the compilation, we need to add a relation with install step.
    b.installArtifact(exe);

    // We can now do: zig build --watch --summary all
    // and run it: ./zig-out/bin/zapi

    // Add the possibility to run tests from src/type_parser.zig
    const parser_mod = b.createModule(.{
        .root_source_file = b.path("src/type_parser.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Compile test step, it creates the executable containing unit tests
    const parser_test = b.addTest(.{
        .root_module = parser_mod,
    });

    // Run step for unit tests
    const run_test = b.addRunArtifact(parser_test);

    const test_step = b.step("test", "Run parser tests");
    test_step.dependOn(&run_test.step);
}
