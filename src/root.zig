const atomic_counter = @import("atomic_counter.zig");
pub const AtomicCounter = atomic_counter.AtomicCounter;

pub const context = @import("context.zig");
pub const Context = context.Context;

pub const errno = @import("errno.zig").errno;
pub const strerror = @import("errno.zig").strerror;

pub const Message = @import("Message.zig");

pub const poll = @import("poll.zig");

pub const poller = @import("poller.zig");
pub const Poller = poller.Poller;

pub const socket = @import("socket.zig");
pub const Socket = socket.Socket;

pub const timers = @import("timers.zig");
pub const Timers = timers.Timers;

pub const curve = @import("curve.zig");
pub const z85 = @import("z85.zig");

pub const Version = struct {
    major: c_int,
    minor: c_int,
    patch: c_int,
};
pub fn version() Version {
    var result: Version = undefined;

    zmq.zmq_version(
        &result.major,
        &result.minor,
        &result.patch,
    );

    return result;
}

pub const Capability = enum { ipc, pgm, tipc, norm, curve, gssapi, draft };
pub fn has(capability: Capability) bool {
    return zmq.zmq_has(std.enums.tagName(Capability, capability).?.ptr) != 0;
}

pub const ProxyError = error{ ContextInvalid, SocketInvalid, Interrupted, Unexpected };
pub fn proxy(frontend: *Socket, backend: *Socket, capture: ?*Socket) ProxyError!void {
    if (zmq.zmq_proxy(frontend, backend, capture) == -1) {
        return switch (errno()) {
            zmq.ETERM => ProxyError.ContextInvalid,
            zmq.EINTR => ProxyError.Interrupted,
            zmq.EFAULT => ProxyError.SocketInvalid,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return ProxyError.Unexpected;
            },
        };
    }
}

pub fn proxySteerable(frontend: *Socket, backend: *Socket, capture: ?*Socket, control: ?*Socket) ProxyError!void {
    if (zmq.zmq_proxy_steerable(frontend, backend, capture, control) == -1) {
        return switch (errno()) {
            zmq.ETERM => ProxyError.ContextInvalid,
            zmq.EINTR => ProxyError.Interrupted,
            zmq.EFAULT => ProxyError.SocketInvalid,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return ProxyError.Unexpected;
            },
        };
    }
}

comptime {
    std.testing.refAllDeclsRecursive(atomic_counter);
    std.testing.refAllDeclsRecursive(context);
    std.testing.refAllDeclsRecursive(Message);
    std.testing.refAllDeclsRecursive(poll);
    std.testing.refAllDeclsRecursive(poller);
    std.testing.refAllDeclsRecursive(socket);
    std.testing.refAllDeclsRecursive(timers);

    if (config.curve) {
        std.testing.refAllDeclsRecursive(curve);
    }
    std.testing.refAllDeclsRecursive(z85);
}

const zmq = @import("libzmq");
const config = @import("config");

const std = @import("std");
const log = std.log.warn;
