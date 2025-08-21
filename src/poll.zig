const std = @import("std");
const zmq = @import("libzmq");
const log = @import("std").log.warn;

const errno = @import("errno.zig").errno;
const strerror = @import("errno.zig").strerror;

const Socket = @import("socket.zig").Socket;
const Events = @import("events.zig").Events;

pub const Item = extern struct {
    socket: ?*Socket = null,
    fd: zmq.zmq_fd_t = 0,
    events: Events = .{},
    revents: Events = .{},
};

pub const PollError = error{ SocketInvalid, Interrupted, Unexpected };
pub fn poll(items: []Item, timeout: c_long) PollError!usize {
    return switch (zmq.zmq_poll(
        @ptrCast(items.ptr),
        @intCast(items.len),
        timeout,
    )) {
        -1 => switch (errno()) {
            // zmq.EFAULT is skip since items cannot be null
            zmq.ETERM => PollError.SocketInvalid,
            zmq.EINTR => PollError.Interrupted,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return PollError.Unexpected;
            },
        },
        else => |size| @intCast(size),
    };
}

pub const sigset_align = @alignOf(zmq.sigset_t);
pub const Sigset = std.posix.system.sigset_t;
pub const PpollError = PollError || error{NotSupported};
pub fn ppoll(
    items: []Item,
    timeout: c_long,
    sigmask: *align(sigset_align) const std.posix.system.sigset_t,
) PpollError!usize {
    return switch (zmq.zmq_ppoll(
        @ptrCast(items.ptr),
        @intCast(items.len),
        timeout,
        @ptrCast(sigmask),
    )) {
        -1 => switch (errno()) {
            // zmq.EFAULT is skip since items cannot be null
            zmq.ETERM => PpollError.SocketInvalid,
            zmq.EINTR => PpollError.Interrupted,
            zmq.ENOTSUP => PpollError.NotSupported,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return PpollError.Unexpected;
            },
        },
        else => |size| @intCast(size),
    };
}

comptime {
    std.debug.assert(@sizeOf(std.posix.system.sigset_t) == @sizeOf(zmq.sigset_t));
}

test poll {
    var items: [1]Item = .{.{}};
    _ = poll(&items, 0) catch {};

    const sigmask: std.posix.sigset_t align(sigset_align) = std.posix.sigemptyset();
    _ = ppoll(&items, 0, &sigmask) catch {};
}
