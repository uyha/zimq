const std = @import("std");
const zimq = @import("zimq");
const zmq = zimq.zmq;

pub fn main() !void {
    const context: *zimq.Context = try .init();
    defer context.deinit();

    const pull: *zimq.Socket = try .init(context, .pull);
    defer pull.deinit();

    const push: *zimq.Socket = try .init(context, .push);
    defer push.deinit();

    try pull.bind("inproc://#1");
    try push.connect("inproc://#1");

    try push.sendSlice("hello", .more);
    try push.sendSlice("hello", .{});

    var message: zimq.Message = .empty();
    _ = try pull.recvMsg(&message, .{});

    std.debug.print("{s}\n", .{message.slice()});

    var routing_id_buffer: [255]u8 = @splat(5);
    var endpoint_buffer: [255:0]u8 = @splat(5);
    try pull.set(.routing_id, "asdf");
    std.debug.print("{s}\n", .{try pull.getSlice(.routing_id, &routing_id_buffer)});
    std.debug.print("{s}\n", .{try pull.getSlice(.last_endpoint, &endpoint_buffer)});

    std.debug.print("{}\n", .{try pull.get(.rcvmore)});
    std.debug.print("{}\n", .{try pull.get(.backlog)});

    std.debug.print("{}\n", .{message.more()});
}
