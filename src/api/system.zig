const tk = @import("tokamak");
const zmpl = @import("zmpl");

const model = @import("../model.zig");
const template = @import("../template.zig");

pub fn @"GET /info"(data: *zmpl.Data, sys_service: *model.SystemService) !template.Template {
    const info = try sys_service.getInfo();
    const root = try data.object();
    try root.put("version", info.version);
    return template.Template.init("system");
}

pub fn @"PUT /info"(data: *zmpl.Data, info: model.ServerInfo) !template.Template {
    const root = try data.object();
    try root.put("version", info.version);
    return template.Template.init("system");
}

pub fn @"GET /info/edit"(data: *zmpl.Data, sys_service: *model.SystemService) !template.Template {
    const info = try sys_service.getInfo();
    const root = try data.object();
    try root.put("version", info.version);
    return template.Template.init("system-edit");
}
