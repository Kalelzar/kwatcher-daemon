const std = @import("std");
const tk = @import("tokamak");
const zmpl = @import("zmpl");

const model = @import("../model.zig");
const template = @import("../template.zig");

pub fn @"GET /overview"(
    data: *zmpl.Data,
    rabbitmq_service: model.RabbitMqService,
    allocator: std.mem.Allocator,
) !template.Template {
    const info = try rabbitmq_service.getOverview(allocator);
    const root = try data.object();
    const value = try zmpl.Data.zmplValue(info, allocator);
    try root.put("overview", value);
    return template.Template.init("rabbitmq-overview");
}
