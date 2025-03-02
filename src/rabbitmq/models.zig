const std = @import("std");

pub const ExchangeType = struct {
    name: []const u8,
    description: []const u8,
    enabled: bool,
};

pub const MessageRate = struct { rate: f32 };

pub const MessageStats = struct {
    get: u32,
    deliver: u32,
    confirm: u32,
    ack: u32,
    publish: u32,
    disk_reads: u32,
    disk_writes: u32,
    get_empty: u32,
    get_no_ack: u32,
    deliver_no_ack: u32,
    redeliver: u32,
    drop_unroutable: u32,
    return_unroutable: u32,
    deliver_get: u32,
    get_empty_details: MessageRate,
    deliver_get_details: MessageRate,
    ack_details: MessageRate,
    redeliver_details: MessageRate,
    deliver_no_ack_details: MessageRate,
    deliver_details: MessageRate,
    get_no_ack_details: MessageRate,
    get_details: MessageRate,
    drop_unroutable_details: MessageRate,
    return_unroutable_details: MessageRate,
    confirm_details: MessageRate,
    publish_details: MessageRate,
    disk_writes_details: MessageRate,
    disk_reads_details: MessageRate,
};

pub const ChurnRates = struct {
    connection_closed: u32,
    queue_declared: u32,
    queue_created: u32,
    connection_created: u32,
    queue_deleted: u32,
    channel_created: u32,
    channel_closed: u32,
    queue_deleted_details: MessageRate,
    queue_created_details: MessageRate,
    queue_declared_details: MessageRate,
    channel_closed_details: MessageRate,
    channel_created_details: MessageRate,
    connection_closed_details: MessageRate,
    connection_created_details: MessageRate,
};

pub const QueueTotals = struct {
    messages: u32,
    messages_ready: u32,
    messages_unacknowledged: u32,
    messages_details: MessageRate,
    messages_unacknowledged_details: MessageRate,
    messages_ready_details: MessageRate,
};

pub const ObjectTotals = struct {
    channels: u32,
    consumers: u32,
    exchanges: u32,
    queues: u32,
    connections: u32,
};

pub const SocketOptions = struct {
    backlog: u32,
    nodelay: bool,
    exit_on_close: bool,
};

pub const Listener = struct {
    node: []const u8,
    protocol: []const u8,
    ip_address: []const u8,
    port: u16,
    socket_opts: SocketOptions,
};

pub const Context = struct {
    ssl_opts: []const struct {},
    node: []const u8,
    description: []const u8,
    path: []const u8,
    cowboy_opts: []const u8,
    port: []const u8,
};

pub const Overview = struct {
    management_version: []const u8,
    rates_mode: []const u8,
    //    exchange_types: []const ExchangeType,
    product_version: []const u8,
    product_name: []const u8,
    rabbitmq_version: []const u8,
    cluster_name: []const u8,
    cluster_tags: struct {},
    node_tags: struct {},
    erlang_version: []const u8,
    erlang_full_version: []const u8,
    disable_stats: bool,
    default_queue_type: []const u8,
    is_op_policy_updating_enabled: bool,
    enable_queue_totals: bool,
    message_stats: MessageStats,
    churn_rates: ChurnRates,
    queue_totals: QueueTotals,
    object_totals: ObjectTotals,
    statistics_db_event_queue: i64,
    node: []const u8,
    //listeners: []const Listener,
    //contexts: []const Context,
};
