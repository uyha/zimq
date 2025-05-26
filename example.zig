const std = @import("std");
const zimq = @import("zimq");

pub fn main() !void {
    const context: *zimq.Context = try .init();
    defer context.deinit();

    const pull: *zimq.Socket = try .init(context, .pull);
    defer pull.deinit();

    const push: *zimq.Socket = try .init(context, .push);
    defer push.deinit();

    try pull.bind("inproc://#1");
    try push.connect("inproc://#1");

    try push.sendSlice("hello", .{});

    var buffer: zimq.Message = .empty();
    _ = try pull.recvMsg(&buffer, .{});

    std.debug.print("{s}\n", .{buffer.slice()});
}
