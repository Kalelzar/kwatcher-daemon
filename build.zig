const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const build_all = b.option(
        bool,
        "all",
        "Build all components. You can still disable individual components",
    ) orelse false;
    const build_exe = b.option(
        bool,
        "exe",
        "Build the application executable",
    ) orelse build_all;
    const build_static_library = b.option(
        bool,
        "lib",
        "Build a static library object",
    ) orelse build_all;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const kwatcher_daemon_library = b.addModule("kwatcher_daemon", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const kwatcher_daemon_exe = b.createModule(.{
        .root_source_file = b.path("src/daemon.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = kwatcher_daemon_library,
    });

    // Artifacts:
    const exe = b.addExecutable(.{
        .name = "kwatcher-daemon",
        .root_module = kwatcher_daemon_exe,
    });
    if (build_exe) {
        b.installArtifact(exe);
    }

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "lib-kwatcher-daemon",
        .root_module = kwatcher_daemon_library,
    });
    if (build_static_library) {
        b.installArtifact(lib);
    }

    const run_tests = b.addRunArtifact(tests);

    const install_docs = b.addInstallDirectory(
        .{
            .source_dir = lib.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        },
    );

    const fmt = b.addFmt(.{
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
        },
        .check = true,
    });

    // Steps:
    const check = b.step("check", "Build without generating artifacts.");
    check.dependOn(&lib.step);
    check.dependOn(&exe.step);

    const test_step = b.step("test", "Run the unit tests.");
    test_step.dependOn(&run_tests.step);
    // - fmt
    const fmt_step = b.step("fmt", "Check formatting");
    fmt_step.dependOn(&fmt.step);
    check.dependOn(fmt_step);
    b.getInstallStep().dependOn(fmt_step);
    // - docs
    const docs_step = b.step("docs", "Generate docs");
    docs_step.dependOn(&install_docs.step);
    docs_step.dependOn(&lib.step);

    // Dependencies:
    // 1st Party:
    const kwevent = b.dependency("kwatcher_event", .{ .target = target, .optimize = optimize });
    const kw = kwevent.builder.dependency("kwatcher", .{
        .target = target,
        .optimize = optimize,
        .lib = true,
        .example = false,
        .dump = false,
    });
    const kwatcher = kw.module("kwatcher");
    const klib = kw.builder.dependency("klib", .{ .target = target, .optimize = optimize }).module("klib");
    const kwatcher_event = kwevent.module("kwatcher_event");
    // 3rd Party:
    const uuid = kw.builder.dependency("uuid", .{ .target = target, .optimize = optimize }).module("uuid");
    const pg = b.dependency("pg", .{ .target = target, .optimize = optimize }).module("pg");
    // Imports:
    // Internal:
    kwatcher_daemon_exe.addImport("kwatcher-daemon", kwatcher_daemon_library);
    // 1st Party:
    kwatcher_daemon_library.addImport("kwatcher-event", kwatcher_event);
    kwatcher_daemon_exe.addImport("kwatcher-event", kwatcher_event);
    kwatcher_daemon_library.addImport("klib", klib);
    kwatcher_daemon_exe.addImport("klib", klib);
    kwatcher_daemon_library.addImport("kwatcher", kwatcher);
    kwatcher_daemon_exe.addImport("kwatcher", kwatcher);
    // 3rd Party:
    kwatcher_daemon_exe.addImport("pg", pg);
    kwatcher_daemon_exe.addImport("uuid", uuid);
    kwatcher_daemon_library.addImport("pg", pg);
    kwatcher_daemon_library.addImport("uuid", uuid);
}
