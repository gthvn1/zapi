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

    // Add the possibility to run tests from src/TypeParser.zig
    const parser_mod = b.createModule(.{
        .root_source_file = b.path("src/TypeParser.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Compile test step, it creates the executable containing unit tests
    const parser_test = b.addTest(.{ .root_module = parser_mod });
    const run_parser_test = b.addRunArtifact(parser_test);

    // We have test for emit as well
    const emit_mod = b.createModule(.{
        .root_source_file = b.path("src/emit.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Compile test step, it creates the executable containing unit tests
    const emit_test = b.addTest(.{ .root_module = emit_mod });
    const run_emit_test = b.addRunArtifact(emit_test);

    // Run step for unit tests
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_parser_test.step);
    test_step.dependOn(&run_emit_test.step);

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
    b.installArtifact(basic_exe);

    // Update the Readme.md if basic.zig is build
    const gen_readme = b.addExecutable(.{
        .name = "gen_readme",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/gen_readme.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_gen = b.addRunArtifact(gen_readme);
    run_gen.addArg("Readme.md");
    // Only run gen_readme if basic_exe compiles.
    run_gen.step.dependOn(&basic_exe.step);
    // As gen_readme is idempotent we can run it for each build. We don't need to
    // install it, we just need to run it when installing other things (basic_exe,
    // and zapi). So that is why we don't do b.installArtifact(gen_readme).
    b.getInstallStep().dependOn(&run_gen.step);
}
