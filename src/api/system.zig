const model = @import("../model.zig");

pub fn @"GET /info"(service: *model.SystemService) !model.ServerInfo {
    return service.getInfo();
}
