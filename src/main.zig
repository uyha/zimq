const zimq = @import("zimq");
const std = @import("std");

pub fn main() !void {
    const context: *zimq.Context = try .init();
    defer context.deinit();

    const socket: *zimq.Socket = try .init(context, .pull);
    defer socket.deinit();

    var message: zimq.Message = .empty();
    defer message.deinit();

    try socket.bind("tcp://*:8080");

    var poller: *zimq.Poller = try .init();
    try poller.add(socket, null, .in);

    var events: [1]zimq.Poller.Event = .{
        .{ .events = .in },
    };

    while (poller.wait(&events[0], -1)) {
        if (events[0].socket == socket) {
            _ = try socket.recvMsg(&message, .{});
            std.debug.print("{?s}\n", .{message.slice()});
        }
    } else |err| {
        std.debug.print("{}\n", .{err});
    }
}
