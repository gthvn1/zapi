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

    // We create a module for the xapi file. This file will be
    // used by the examples.
    const xapi_mod = b.createModule(.{
        .root_source_file = b.path("src/xapi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const basic_exe = b.addExecutable(.{
        .name = "basic",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    basic_exe.root_module.addImport("xapi", xapi_mod);

    const basic_run = b.addRunArtifact(basic_exe);
    const examples_step = b.step("examples", "Run examples");
    examples_step.dependOn(&basic_run.step);
}
