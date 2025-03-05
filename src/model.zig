const std = @import("std");

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
