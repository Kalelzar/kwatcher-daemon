const std = @import("std");
const builtin = @import("builtin");

const Builder = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    opt: std.builtin.OptimizeMode,
    check_step: *std.Build.Step,
    httpz: *std.Build.Module,
    klib: *std.Build.Module,
    kwatcher: *std.Build.Module,
    kwatcher_daemon: *std.Build.Module,
    kwatcher_http: *std.Build.Module,
    kwatcher_daemon_lib: *std.Build.Module,
    tokamak: *std.Build.Module,
    metrics: *std.Build.Module,
    pg: *std.Build.Module,
    uuid: *std.Build.Module,
    zmpl: *std.Build.Module,

    fn init(b: *std.Build) Builder {
        const target = b.standardTargetOptions(.{});
        const opt = b.standardOptimizeOption(.{});

        const check_step = b.step("check", "");
        const embed: []const []const u8 = &.{
            "static/index.html",
        };
        const klib = b.dependency("klib", .{ .target = target, .optimize = opt }).module("klib");
        const tk = b.dependency("tokamak", .{ .embed = embed, .target = target, .optimize = opt });
        const tokamak = tk.module("tokamak");
        const hz = tk.builder.dependency("httpz", .{ .target = target, .optimize = opt });
        const httpz = hz.module("httpz");
        const metrics = hz.builder.dependency("metrics", .{ .target = target, .optimize = opt }).module("metrics");
        const zmpl = b.dependency("zmpl", .{ .target = target, .optimize = opt }).module("zmpl");
        const kw = b.dependency("kwatcher", .{ .target = target, .optimize = opt });
        const kwatcher = kw.module("kwatcher");
        const uuid = kw.builder.dependency("uuid", .{ .target = target, .optimize = opt }).module("uuid");
        const pg = b.dependency("pg", .{ .target = target, .optimize = opt }).module("pg");

        const kwatcher_daemon_lib = b.addModule("kawatcher-daemon", .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = opt,
        });
        kwatcher_daemon_lib.link_libc = true;
        kwatcher_daemon_lib.addImport("tokamak", tokamak);
        kwatcher_daemon_lib.addImport("kwatcher", kwatcher);
        kwatcher_daemon_lib.addImport("zmpl", zmpl);
        kwatcher_daemon_lib.addImport("pg", pg);
        kwatcher_daemon_lib.addImport("uuid", uuid);
        kwatcher_daemon_lib.addImport("klib", klib);

        const kwatcher_http = b.createModule(.{
            .root_source_file = b.path("src/http.zig"),
            .target = target,
            .optimize = opt,
        });
        kwatcher_http.link_libc = true;
        kwatcher_http.addImport("pg", pg);
        kwatcher_http.addImport("kwatcher-daemon", kwatcher_daemon_lib);
        kwatcher_http.addImport("tokamak", tokamak);
        kwatcher_http.addImport("zmpl", zmpl);
        kwatcher_http.addImport("httpz", httpz);
        kwatcher_http.addImport("metrics", metrics);
        kwatcher_http.addImport("uuid", uuid);
        kwatcher_http.addImport("klib", klib);

        const kwatcher_daemon = b.createModule(.{
            .root_source_file = b.path("src/daemon.zig"),
            .target = target,
            .optimize = opt,
        });
        kwatcher_daemon.link_libc = true;
        kwatcher_daemon.addImport("kwatcher", kwatcher);
        kwatcher_daemon.addImport("kwatcher-daemon", kwatcher_daemon_lib);
        kwatcher_daemon.addImport("pg", pg);
        kwatcher_daemon.addImport("uuid", uuid);
        kwatcher_daemon.addImport("klib", klib);

        return .{
            .b = b,
            .check_step = check_step,
            .target = target,
            .opt = opt,
            .kwatcher = kwatcher,
            .kwatcher_daemon = kwatcher_daemon,
            .kwatcher_http = kwatcher_http,
            .kwatcher_daemon_lib = kwatcher_daemon_lib,
            .tokamak = tokamak,
            .metrics = metrics,
            .httpz = httpz,
            .zmpl = zmpl,
            .pg = pg,
            .uuid = uuid,
            .klib = klib,
        };
    }

    fn addDependencies(
        self: *Builder,
        step: *std.Build.Step.Compile,
    ) void {
        step.linkLibC();
        step.linkSystemLibrary("rabbitmq");
        step.root_module.addImport("tokamak", self.tokamak);
        step.root_module.addImport("kwatcher", self.kwatcher);
        step.root_module.addImport("httpz", self.httpz);
        step.root_module.addImport("metrics", self.metrics);
        step.root_module.addImport("zmpl", self.zmpl);
        step.root_module.addImport("pg", self.pg);
        step.root_module.addImport("uuid", self.uuid);
        step.root_module.addImport("klib", self.klib);
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

    const http = builder.addExecutable("kwatcher-server", "src/http.zig");
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
