const std = @import("std");
const log = std.log.warn;
const zmq = @import("libzmq");

const errno = @import("errno.zig").errno;
const strerror = @import("errno.zig").strerror;

const Events = @import("events.zig").Events;
const Socket = @import("socket.zig").Socket;

pub const Poller = opaque {
    const Self = @This();

    pub const InitError = error{ NoMemory, Unexpected };
    pub fn init() InitError!*Self {
        if (zmq.zmq_poller_new()) |handle| {
            return @ptrCast(handle);
        } else {
            switch (errno()) {
                zmq.ENOMEM => return InitError.NoMemory,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return InitError.Unexpected;
                },
            }
        }
    }
    pub fn deinit(self: *Self) void {
        var temp: ?*Self = self;
        _ = zmq.zmq_poller_destroy(@ptrCast(&temp));
    }

    test init {
        var poller: *Self = try .init();
        poller.deinit();
    }

    pub const AddError = error{
        SocketInvalid,
        TooManyFilesPolled,
        NoMemory,
        SocketAdded,
        Unexpected,
    };
    pub fn add(
        self: *Self,
        socket: *Socket,
        data: ?*anyopaque,
        events: Events,
    ) AddError!void {
        if (zmq.zmq_poller_add(
            self,
            socket,
            data,
            @bitCast(events),
        ) == -1) {
            switch (errno()) {
                zmq.ENOTSOCK => return AddError.SocketInvalid,
                zmq.EMFILE => return AddError.TooManyFilesPolled,
                zmq.ENOMEM => return AddError.NoMemory,
                zmq.EINVAL => return AddError.SocketAdded,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return AddError.Unexpected;
                },
            }
        }
    }

    pub const ModifyError = error{ SocketInvalid, SocketNotAdded, Unexpected };
    pub fn modify(
        self: *Self,
        socket: *Socket,
        events: Events,
    ) ModifyError!void {
        if (zmq.zmq_poller_modify(
            self,
            socket,
            @bitCast(events),
        ) == -1) {
            switch (errno()) {
                zmq.ENOTSOCK => return ModifyError.SocketInvalid,
                zmq.EINVAL => return ModifyError.SocketNotAdded,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return ModifyError.Unexpected;
                },
            }
        }
    }

    pub const RemoveError = error{ SocketInvalid, SocketNotAdded, Unexpected };
    pub fn remove(self: *Self, socket: *Socket) RemoveError!void {
        if (zmq.zmq_poller_remove(self, socket) == -1) {
            switch (errno()) {
                zmq.ENOTSOCK => return RemoveError.SocketInvalid,
                zmq.EINVAL => return RemoveError.SocketNotAdded,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return RemoveError.Unexpected;
                },
            }
        }
    }

    pub fn size(self: *Self) usize {
        const result = zmq.zmq_poller_size(self);
        std.debug.assert(result >= 0);
        return @intCast(result);
    }

    test add {
        const t = @import("std").testing;

        const Context = @import("context.zig").Context;

        const context: *Context = try .init();
        defer context.deinit();

        const socket: *Socket = try .init(context, .sub);
        defer socket.deinit();

        var poller: *Self = try .init();
        defer poller.deinit();

        try poller.add(socket, null, .in);
        try t.expectEqual(1, poller.size());
    }
    test modify {
        const t = @import("std").testing;

        const Context = @import("context.zig").Context;

        const context: *Context = try .init();
        defer context.deinit();

        const socket: *Socket = try .init(context, .sub);
        defer socket.deinit();

        var poller: *Self = try .init();
        defer poller.deinit();

        try poller.add(socket, null, .in);
        try poller.modify(socket, .inout);
        try t.expectEqual(1, poller.size());
    }
    test remove {
        const t = @import("std").testing;

        const Context = @import("context.zig").Context;

        const context: *Context = try .init();
        defer context.deinit();

        const socket: *Socket = try .init(context, .sub);
        defer socket.deinit();

        var poller: *Self = try .init();
        defer poller.deinit();

        try poller.add(socket, null, .in);
        try t.expectEqual(1, poller.size());
        try poller.remove(socket);
        try t.expectEqual(0, poller.size());
    }

    pub const AddFdError = error{
        NoMemory,
        FdAdded,
        FdInvalid,
        Unexpected,
    };
    pub fn addFd(
        self: *Self,
        file: zmq.zmq_fd_t,
        data: ?*anyopaque,
        events: Events,
    ) AddFdError!void {
        if (zmq.zmq_poller_add_fd(
            self,
            file,
            data,
            @bitCast(events),
        ) == -1) {
            switch (errno()) {
                zmq.ENOMEM => return AddFdError.NoMemory,
                zmq.EINVAL => return AddFdError.FdAdded,
                zmq.EBADF => return AddFdError.FdInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return AddFdError.Unexpected;
                },
            }
        }
    }

    pub const ModifyFdError = error{
        FdNotAdded,
        FdInvalid,
        Unexpected,
    };
    pub fn modifyFd(
        self: *Self,
        file: zmq.zmq_fd_t,
        events: Events,
    ) ModifyFdError!void {
        if (zmq.zmq_poller_modify_fd(
            self,
            file,
            @bitCast(events),
        ) == -1) {
            switch (errno()) {
                zmq.EINVAL => return ModifyFdError.FdNotAdded,
                zmq.EBADF => return ModifyFdError.FdInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return ModifyFdError.Unexpected;
                },
            }
        }
    }

    pub const RemoveFdError = error{
        FdNotAdded,
        FdInvalid,
        Unexpected,
    };
    pub fn removeFd(
        self: *Self,
        file: zmq.zmq_fd_t,
    ) RemoveFdError!void {
        if (zmq.zmq_poller_remove_fd(self, file) == -1) {
            switch (errno()) {
                zmq.EINVAL => return ModifyFdError.FdNotAdded,
                zmq.EBADF => return ModifyFdError.FdInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return ModifyFdError.Unexpected;
                },
            }
        }
    }

    test addFd {
        const t = @import("std").testing;

        var poller: *Self = try .init();
        defer poller.deinit();

        try poller.addFd(1, null, .in);
        try t.expectEqual(1, poller.size());
    }
    test modifyFd {
        const t = @import("std").testing;

        var poller: *Self = try .init();
        defer poller.deinit();

        try poller.addFd(1, null, .in);
        try poller.modifyFd(1, .inout);
        try t.expectEqual(1, poller.size());
    }
    test removeFd {
        const t = @import("std").testing;

        var poller: *Self = try .init();
        defer poller.deinit();

        try poller.addFd(1, null, .in);
        try t.expectEqual(1, poller.size());

        try poller.removeFd(1);
        try t.expectEqual(0, poller.size());
    }

    pub const FdError = error{Unexpected};
    pub fn fd(self: *Self) FdError!?zmq.zmq_fd_t {
        var result: zmq.zmq_fd_t = undefined;

        if (zmq.zmq_poller_fd(self, &result) == -1) {
            switch (errno()) {
                zmq.EINVAL => return null,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return ModifyFdError.Unexpected;
                },
            }
        }

        return result;
    }

    test fd {
        var poller: *Self = try .init();
        defer poller.deinit();

        if (poller.fd()) |_| {} else |_| {}
    }

    pub const Event = extern struct {
        socket: ?*Socket = null,
        fd: zmq.zmq_fd_t = 0,
        data: ?*anyopaque = null,
        events: Events = .{},
    };

    pub const WaitError = error{ NoMemory, SocketInvalid, SubscriptionInvalid, Interrupted, NoEvent, Unexpected };
    pub fn wait(self: *Self, event: *Event, timeout: c_long) WaitError!void {
        if (zmq.zmq_poller_wait(
            self,
            @ptrCast(event),
            timeout,
        ) == -1) {
            return switch (errno()) {
                zmq.ENOMEM => WaitError.NoMemory,
                zmq.ETERM => WaitError.SocketInvalid,
                zmq.EFAULT => WaitError.SubscriptionInvalid,
                zmq.EINTR => WaitError.Interrupted,
                zmq.EAGAIN => WaitError.NoEvent,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return WaitError.Unexpected;
                },
            };
        }
    }

    pub fn waitAll(self: *Self, events: []Event, timeout: c_long) WaitError!usize {
        return switch (zmq.zmq_poller_wait_all(self, @ptrCast(events.ptr), @intCast(events.len), timeout)) {
            -1 => switch (errno()) {
                zmq.ENOMEM => WaitError.NoMemory,
                zmq.ETERM => WaitError.SocketInvalid,
                zmq.EFAULT => WaitError.SubscriptionInvalid,
                zmq.EINTR => WaitError.Interrupted,
                zmq.EAGAIN => WaitError.NoEvent,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return WaitError.Unexpected;
                },
            },
            else => |event_size| @intCast(event_size),
        };
    }

    test wait {
        var poller: *Self = try .init();
        defer poller.deinit();

        var event: Event = .{ .fd = 1, .events = .in };
        poller.wait(&event, 0) catch {};
    }
    test waitAll {
        var poller: *Self = try .init();
        defer poller.deinit();

        var events: [1]Event = .{undefined};
        _ = poller.waitAll(&events, 0) catch {};
    }
};
