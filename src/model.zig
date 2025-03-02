const std = @import("std");
const rabbitmq = @import("rabbitmq/models.zig");

pub const ServerInfo = struct {
    version: []const u8,
};

pub const SystemService = struct {
    pub fn init() !SystemService {
        return .{};
    }

    pub fn getInfo(self: *SystemService) !ServerInfo {
        _ = self;
        return .{
            .version = "1.0.0",
        };
    }
};

pub const RabbitMqService = struct {
    pub fn init() !RabbitMqService {
        return .{};
    }

    pub fn getOverview(self: *const RabbitMqService, allocator: std.mem.Allocator) !rabbitmq.Overview {
        _ = self;

        // Create a HTTP client
        var client = std.http.Client{ .allocator = allocator };
        defer client.deinit();

        // Allocate a buffer for server headers
        var buf: [4096]u8 = undefined;

        // Start the HTTP request
        const uri = try std.Uri.parse("http://localhost:15672/api/overview");
        var req = try client.open(.GET, uri, .{ .server_header_buffer = &buf });
        defer req.deinit();
        req.headers.authorization = .{
            .override = "Basic Z3Vlc3Q6Z3Vlc3Q=",
        };

        // Send the HTTP request headers
        try req.send();
        // Finish the body of a request
        try req.finish();

        // Waits for a response from the server and parses any headers that are sent
        try req.wait();

        if (req.response.status != std.http.Status.ok) {
            return error.UnknownError;
        }

        var reader = std.json.reader(allocator, req.reader());
        return std.json.parseFromTokenSourceLeaky(
            rabbitmq.Overview,
            allocator,
            &reader,
            .{
                .ignore_unknown_fields = true,
                .duplicate_field_behavior = .use_last,
            },
        );
    }
};
