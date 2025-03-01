const std = @import("std");
const builtin = @import("builtin");

const Builder = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    check_step: *std.Build.Step,
    tokamak: *std.Build.Module,
    kwatcher: *std.Build.Module,
    kwatcher_daemon: *std.Build.Module,
    kwatcher_http: *std.Build.Module,
    kwatcher_daemon_lib: *std.Build.Module,

    fn init(b: *std.Build) Builder {
        const target = b.standardTargetOptions(.{});
        const opt = b.standardOptimizeOption(.{});

        const check_step = b.step("check", "");

        const tokamak = b.dependency("tokamak", .{}).module("tokamak");
        const kwatcher = b.dependency("kwatcher", .{}).module("kwatcher");
        const kwatcher_daemon_lib = b.addModule("kawatcher-daemon", .{
            .root_source_file = b.path("src/root.zig"),
        });
        kwatcher_daemon_lib.link_libc = true;
        kwatcher_daemon_lib.addImport("tokamak", tokamak);
        kwatcher_daemon_lib.addImport("kwatcher", kwatcher);

        const kwatcher_http = b.createModule(.{
            .root_source_file = b.path("src/http.zig"),
        });
        kwatcher_http.link_libc = true;
        kwatcher_http.addImport("tokamak", tokamak);
        kwatcher_http.addImport("kwatcher-daemon", kwatcher_daemon_lib);

        const kwatcher_daemon = b.createModule(.{
            .root_source_file = b.path("src/daemon.zig"),
        });
        kwatcher_daemon.link_libc = true;
        kwatcher_daemon.addImport("kwatcher", kwatcher);
        kwatcher_daemon.addImport("kwatcher-daemon", kwatcher_daemon_lib);

        return .{
            .b = b,
            .check_step = check_step,
            .target = target,
            .opt = opt,
            .tokamak = tokamak,
            .kwatcher = kwatcher,
            .kwatcher_daemon = kwatcher_daemon,
            .kwatcher_http = kwatcher_http,
            .kwatcher_daemon_lib = kwatcher_daemon_lib,
        };
    }

    fn addDependencies(
        self: *Builder,
        step: *std.Build.Step.Compile,
    ) void {
        step.linkLibC();
        step.linkSystemLibrary("rabbitmq.4");
        step.root_module.addImport("tokamak", self.tokamak);
        step.root_module.addImport("kwatcher", self.kwatcher);
        step.addLibraryPath(.{ .cwd_relative = "." });
        step.addLibraryPath(.{ .cwd_relative = "." });
    }

    fn addExecutable(self: *Builder, name: []const u8, root_source_file: []const u8) *std.Build.Step.Compile {
        return self.b.addExecutable(.{
            .name = name,
            .root_source_file = self.b.path(root_source_file),
            .target = self.target,
            .optimize = self.opt,
        });
    }

    fn addStaticLibrary(self: *Builder, name: []const u8, root_source_file: []const u8) *std.Build.Step.Compile {
        return self.b.addStaticLibrary(.{
            .name = name,
            .root_source_file = self.b.path(root_source_file),
            .target = self.target,
            .optimize = self.opt,
        });
    }

    fn addTest(self: *Builder, name: []const u8, root_source_file: []const u8) *std.Build.Step.Compile {
        return self.b.addTest(.{
            .name = name,
            .root_source_file = self.b.path(root_source_file),
            .target = self.target,
            .optimize = self.opt,
        });
    }

    fn installAndCheck(self: *Builder, exe: *std.Build.Step.Compile) !void {
        const check_exe = try self.b.allocator.create(std.Build.Step.Compile);
        check_exe.* = exe.*;
        self.check_step.dependOn(&check_exe.step);
        self.b.installArtifact(exe);
    }
};

pub fn build(b: *std.Build) !void {
    var builder = Builder.init(b);

    const lib = builder.addStaticLibrary("kwatcher-daemon-lib", "src/root.zig");
    builder.addDependencies(lib);
    try builder.installAndCheck(lib);

    const daemon = builder.addExecutable("kwatcher-daemon", "src/daemon.zig");
    builder.addDependencies(daemon);
    try builder.installAndCheck(daemon);
    daemon.root_module.addImport("kwatcher-daemon", builder.kwatcher_daemon_lib);

    const http = builder.addExecutable("kwatcher-daemon", "src/http.zig");
    builder.addDependencies(http);
    try builder.installAndCheck(http);
    http.root_module.addImport("kwatcher-daemon", builder.kwatcher_daemon_lib);

    const run_cmd = b.addRunArtifact(http);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
