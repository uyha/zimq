const std = @import("std");
const log = std.log.warn;
const c = std.c;
const zmq = @import("libzmq");

const Context = @import("context.zig").Context;
const Message = @import("Message.zig");

const opt = @import("socket/option.zig");
const SetOption = opt.SetOption;
const SetOptionType = opt.SetOptionType;
const GetOption = opt.GetOption;
const GetOptionType = opt.GetOptionType;
const Mechanism = opt.Mechanism;
const ReconnectStop = opt.ReconnectStop;
const RouterNotify = opt.RouterNotify;
const NormMode = opt.NormMode;
const PrincipalNameType = opt.PrincipalNameType;

pub const Type = @import("socket/type.zig").Type;

const poll = @import("poll.zig");

const errno = @import("errno.zig").errno;
const strerror = @import("errno.zig").strerror;

pub const Socket = opaque {
    const Self = @This();

    pub const InitError = error{
        TooManyOpenFiles,
        InvalidContext,
        Unexpected,
    };
    pub fn init(context: *Context, socket_type: Type) InitError!*Self {
        if (zmq.zmq_socket(context, @intFromEnum(socket_type))) |handle| {
            return @ptrCast(handle);
        } else {
            return switch (errno()) {
                zmq.EMFILE => InitError.TooManyOpenFiles,
                zmq.EFAULT, zmq.ETERM => InitError.InvalidContext,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return InitError.Unexpected;
                },
            };
        }
    }
    pub fn deinit(self: *Self) void {
        _ = zmq.zmq_close(self);
    }

    test init {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();
    }

    pub const ConnectError = error{
        EndpointInvalid,
        TransportNotSupported,
        TransportNotCompatible,
        ContextInvalid,
        SocketInvalid,
        NoThreadAvaiable,
        Unexpected,
    };
    pub fn connect(self: *Self, endpoint: [:0]const u8) ConnectError!void {
        if (zmq.zmq_connect(self, endpoint.ptr) != -1) {
            return;
        }

        return switch (errno()) {
            zmq.EINVAL => ConnectError.EndpointInvalid,
            zmq.ETERM => ConnectError.ContextInvalid,
            zmq.ENOTSOCK => ConnectError.SocketInvalid,
            zmq.EPROTONOSUPPORT => ConnectError.TransportNotSupported,
            zmq.ENOCOMPATPROTO => ConnectError.TransportNotCompatible,
            zmq.EMTHREAD => ConnectError.NoThreadAvaiable,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return ConnectError.Unexpected;
            },
        };
    }

    test connect {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        socket.connect("ipc://asdf") catch {};
        socket.disconnect("ipc://asdf") catch {};
    }

    pub const ConnectPeerError = ConnectError || error{SocketNotPeer};
    pub fn connectPeer(self: *Self, endpoint: [:0]const u8) ConnectPeerError!void {
        if (zmq.zmq_connect_peer(self, endpoint.ptr) != -1) {
            return;
        }

        return switch (errno()) {
            zmq.EINVAL => ConnectPeerError.EndpointInvalid,
            zmq.ETERM => ConnectPeerError.ContextInvalid,
            zmq.ENOTSOCK => ConnectPeerError.SocketInvalid,
            zmq.EPROTONOSUPPORT => ConnectPeerError.TransportNotSupported,
            zmq.ENOCOMPATPROTO => ConnectPeerError.TransportNotCompatible,
            zmq.EMTHREAD => ConnectPeerError.NoThreadAvaiable,
            zmq.ENOTSUP => ConnectPeerError.SocketNotPeer,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return ConnectPeerError.Unexpected;
            },
        };
    }

    test connectPeer {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        socket.connectPeer("ipc://asdf") catch {};
        socket.disconnect("ipc://asdf") catch {};
    }

    pub const DisconnectError = error{
        EndpointInvalid,
        ContextInvalid,
        SocketInvalid,
        EndpointNotBound,
        Unexpected,
    };
    pub fn disconnect(self: *Self, endpoint: [:0]const u8) DisconnectError!void {
        if (zmq.zmq_disconnect(self, endpoint.ptr) != -1) {
            return;
        }

        return switch (errno()) {
            zmq.EINVAL => DisconnectError.EndpointInvalid,
            zmq.ETERM => DisconnectError.ContextInvalid,
            zmq.ENOTSOCK => DisconnectError.SocketInvalid,
            zmq.ENOENT => DisconnectError.EndpointNotBound,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return DisconnectError.Unexpected;
            },
        };
    }

    pub const BindError = error{
        EndpointInvalid,
        TransportNotSupported,
        TransportNotCompatible,
        AddressInUse,
        AddressNotLocal,
        NonexistentInterface,
        ContextInvalid,
        SocketInvalid,
        NoThreadAvaiable,
        Unexpected,
    };
    pub fn bind(self: *Self, endpoint: [:0]const u8) BindError!void {
        if (zmq.zmq_bind(self, endpoint.ptr) != -1) {
            return;
        }
        return switch (errno()) {
            zmq.EINVAL => BindError.EndpointInvalid,
            zmq.EPROTONOSUPPORT => BindError.TransportNotSupported,
            zmq.ENOCOMPATPROTO => BindError.TransportNotCompatible,
            zmq.EADDRINUSE => BindError.AddressInUse,
            zmq.EADDRNOTAVAIL => BindError.AddressNotLocal,
            zmq.ENODEV => BindError.NonexistentInterface,
            zmq.ETERM => BindError.ContextInvalid,
            zmq.ENOTSOCK => BindError.SocketInvalid,
            zmq.EMTHREAD => BindError.NoThreadAvaiable,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return BindError.Unexpected;
            },
        };
    }

    test bind {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        try socket.bind("inproc://#1");
    }

    pub const UnbindError = error{
        EndpointInvalid,
        ContextInvalid,
        SocketInvalid,
        EndpointNotBound,
        Unexpected,
    };
    pub fn unbind(self: *Self, endpoint: [:0]const u8) UnbindError!void {
        if (zmq.zmq_unbind(self, endpoint.ptr) != -1) {
            return;
        }
        return switch (errno()) {
            zmq.EINVAL => UnbindError.EndpointInvalid,
            zmq.ETERM => UnbindError.ContextInvalid,
            zmq.ENOTSOCK => UnbindError.SocketInvalid,
            zmq.ENOENT => UnbindError.EndpointNotBound,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return UnbindError.Unexpected;
            },
        };
    }
    test unbind {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        try socket.bind("inproc://#1");
        try socket.unbind("inproc://#1");
    }

    pub const SendFlags = packed struct(c_int) {
        dont_wait: bool = false,
        send_more: bool = false,
        _padding: u30 = 0,

        pub const noblock: SendFlags = .{ .dont_wait = true };
        pub const more: SendFlags = .{ .send_more = true };
        pub const morenoblock: SendFlags = .{ .dont_wait = true, .send_more = true };
    };
    pub const SendError = error{
        WouldBlock,
        SendNotSupported,
        MultipartNotSupported,
        InappropriateStateActionFailed,
        ContextInvalid,
        SocketInvalid,
        Interrupted,
        MessageInvalid,
        CannotRoute,
        Unexpected,
    };

    fn sendError(err: c_int) SendError {
        return switch (err) {
            zmq.EAGAIN => SendError.WouldBlock,
            zmq.ENOTSUP => SendError.SendNotSupported,
            zmq.EINVAL => SendError.MultipartNotSupported,
            zmq.EFSM => SendError.InappropriateStateActionFailed,
            zmq.ETERM => SendError.ContextInvalid,
            zmq.ENOTSOCK => SendError.SocketInvalid,
            zmq.EINTR => SendError.Interrupted,
            zmq.EFAULT => SendError.MessageInvalid,
            zmq.EHOSTUNREACH => SendError.CannotRoute,
            else => {
                log("{s}\n", .{strerror(err)});
                return SendError.Unexpected;
            },
        };
    }
    pub fn sendMsg(self: *Self, message: *Message, flags: SendFlags) SendError!void {
        const result = zmq.zmq_msg_send(&message.message, self, @bitCast(flags));
        if (result == -1) {
            return sendError(errno());
        }
    }
    test sendMsg {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        var msg: Message = .empty();
        defer msg.deinit();

        socket.sendMsg(&msg, .{}) catch {};
    }

    pub fn sendSlice(self: *Self, slice: []const u8, flags: SendFlags) SendError!void {
        return self.sendBuffer(slice.ptr, slice.len, flags);
    }
    test sendSlice {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        socket.sendSlice("", .{}) catch {};
    }

    pub fn sendConstSlice(self: *Self, slice: []const u8, flags: SendFlags) SendError!void {
        return self.sendConst(slice.ptr, slice.len, flags);
    }
    test sendConstSlice {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        socket.sendConstSlice("", .{}) catch {};
    }

    pub fn sendBuffer(self: *Self, ptr: *const anyopaque, len: usize, flags: SendFlags) SendError!void {
        const result = zmq.zmq_send(self, ptr, len, @bitCast(flags));
        if (result == -1) {
            return sendError(errno());
        }
    }
    test sendBuffer {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        socket.sendBuffer("", 0, .{}) catch {};
    }

    pub fn sendConst(self: *Self, ptr: *const anyopaque, len: usize, flags: SendFlags) SendError!void {
        const result = zmq.zmq_send_const(self, ptr, len, @bitCast(flags));
        if (result == -1) {
            return sendError(errno());
        }
    }
    test sendConst {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        socket.sendConst("", 0, .{}) catch {};
    }

    pub const RecvFlags = packed struct(c_int) {
        dont_wait: bool = false,
        _padding: u31 = 0,

        pub const noblock: RecvFlags = .{ .dont_wait = true };
    };
    pub const RecvError = error{
        WouldBlock,
        RecvNotSupported,
        InappropriateStateActionFailed,
        ContextInvalid,
        SocketInvalid,
        Interrupted,
        Unexpected,
    };
    fn recvError(err: c_int) RecvError {
        return switch (err) {
            zmq.EAGAIN => RecvError.WouldBlock,
            zmq.ENOTSUP => RecvError.RecvNotSupported,
            zmq.EFSM => RecvError.InappropriateStateActionFailed,
            zmq.ETERM => RecvError.ContextInvalid,
            zmq.ENOTSOCK => RecvError.SocketInvalid,
            zmq.EINTR => RecvError.Interrupted,
            else => {
                log("{s}\n", .{strerror(err)});
                return RecvError.Unexpected;
            },
        };
    }
    pub fn recv(self: *Self, buffer: []u8, flags: RecvFlags) RecvError!usize {
        return switch (zmq.zmq_recv(self, buffer.ptr, buffer.len, @bitCast(flags))) {
            -1 => recvError(errno()),
            else => |size| @intCast(size),
        };
    }

    test recv {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        var buffer: [16]u8 = undefined;
        var slice: []u8 = &buffer;

        slice.len = socket.recv(slice, .noblock) catch 0;
    }

    pub const RecvMsgError = RecvError || error{MessageInvalid};
    pub fn recvMsg(self: *Self, msg: *Message, flags: RecvFlags) RecvMsgError!usize {
        return result: switch (zmq.zmq_recvmsg(self, &msg.message, @bitCast(flags))) {
            -1 => {
                const err = errno();
                break :result switch (err) {
                    zmq.EFAULT => RecvMsgError.MessageInvalid,
                    else => recvError(err),
                };
            },
            else => |size| @intCast(size),
        };
    }

    test recvMsg {
        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        var msg: Message = .empty();
        defer msg.deinit();

        _ = socket.recvMsg(&msg, .noblock) catch {};
    }

    pub const SetError = error{
        OptionInvalid,
        ContextInvalid,
        SocketInvalid,
        Interrupted,
        Unexpected,
    };
    pub fn set(self: *Self, comptime option: SetOption, value: SetOptionType(option)) SetError!void {
        const Value = @TypeOf(value);
        const raw_value = switch (@typeInfo(Value)) {
            .bool => @as(c_int, @intFromBool(value)),
            .@"struct" => |Struct| switch (Struct.layout) {
                .@"packed" => @as(Struct.backing_integer.?, @bitCast(value)),
                else => @compileError("Unrecognized type: " ++ @typeName(Value)),
            },
            .@"enum" => @intFromEnum(value),
            .int, .pointer => value,
            else => @compileError("Unrecognized type: " ++ @typeName(Value)),
        };
        const RawValue = @TypeOf(raw_value);

        const ptr, const size = switch (RawValue) {
            []const u8, [:0]const u8 => .{ raw_value.ptr, raw_value.len },
            c_int, u64, i64 => .{ &raw_value, @sizeOf(RawValue) },
            else => @compileError("Unrecognized type: " ++ @typeName(RawValue)),
        };

        if (zmq.zmq_setsockopt(
            self,
            @intFromEnum(option),
            ptr,
            size,
        ) == 0) {
            return;
        }

        return switch (errno()) {
            zmq.EINVAL => SetError.OptionInvalid,
            zmq.ETERM => SetError.ContextInvalid,
            zmq.ENOTSOCK => SetError.SocketInvalid,
            zmq.EINTR => SetError.Interrupted,
            else => |err| {
                log("{s}\n", .{strerror(err)});
                return SetError.Unexpected;
            },
        };
    }

    pub const GetError = error{
        OptionInvalid,
        ContextInvalid,
        SocketInvalid,
        Interrupted,
        Unexpected,
    };
    pub fn get(self: *Self, comptime option: GetOption, out: *GetOptionType(option)) SetError!void {
        const Out = @TypeOf(out.*);
        const result = result: switch (@typeInfo(Out)) {
            .bool => {
                var value: c_int = undefined;
                var size: usize = @sizeOf(@TypeOf(value));

                const result = zmq.zmq_getsockopt(self, @intFromEnum(option), &value, &size);

                if (result != -1) {
                    out.* = value != 0;
                }

                break :result result;
            },
            .@"struct" => |Struct| {
                if (Struct.layout != .@"packed") {
                    @compileError("Unrecognized type: " ++ @typeName(Out));
                }
                var size: usize = @sizeOf(Out);
                break :result zmq.zmq_getsockopt(self, @intFromEnum(option), out, &size);
            },
            .@"enum" => {
                var size: usize = @sizeOf(Out);
                break :result zmq.zmq_getsockopt(self, @intFromEnum(option), out, &size);
            },
            .int => {
                var size: usize = @sizeOf(Out);
                break :result zmq.zmq_getsockopt(self, @intFromEnum(option), out, &size);
            },
            .pointer => |Pointer| {
                if (Pointer.size != .slice) {
                    @compileError("Unrecognized type: " ++ @typeName(Out));
                }
                break :result zmq.zmq_getsockopt(
                    self,
                    @intFromEnum(option),
                    out.ptr,
                    &out.len,
                );
            },
            else => @compileError("Unrecognized type: " ++ @typeName(Out)),
        };

        if (result == -1) {
            return switch (errno()) {
                zmq.EINVAL => SetError.OptionInvalid,
                zmq.ETERM => SetError.ContextInvalid,
                zmq.ENOTSOCK => SetError.SocketInvalid,
                zmq.EINTR => SetError.Interrupted,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return SetError.Unexpected;
                },
            };
        }
    }

    pub fn MonitorVersionedEvent(version: EventVersion) type {
        return switch (version) {
            .v1 => packed struct(c_int) {
                connected: bool = false, // 0x00001
                connect_delayed: bool = false, // 0x00002
                connect_retried: bool = false, // 0x00004
                listening: bool = false, // 0x00008
                bind_failed: bool = false, // 0x00010
                accepted: bool = false, // 0x00020
                accept_failed: bool = false, // 0x00040
                closed: bool = false, // 0x00080
                close_failed: bool = false, // 0x00100
                disconnected: bool = false, // 0x00200
                monitor_stopped: bool = false, // 0x00400
                handshake_failed_no_detail: bool = false, // 0x00800
                handshake_succeeded: bool = false, // 0x01000
                handshake_failed_protocol: bool = false, // 0x02000
                handshake_failed_auth: bool = false, // 0x04000
                _padding: u17 = 0,
            },
            .v2 => packed struct(u64) {
                connected: bool = false, // 0x00001
                connect_delayed: bool = false, // 0x00002
                connect_retried: bool = false, // 0x00004
                listening: bool = false, // 0x00008
                bind_failed: bool = false, // 0x00010
                accepted: bool = false, // 0x00020
                accept_failed: bool = false, // 0x00040
                closed: bool = false, // 0x00080
                close_failed: bool = false, // 0x00100
                disconnected: bool = false, // 0x00200
                monitor_stopped: bool = false, // 0x00400
                handshake_failed_no_detail: bool = false, // 0x00800
                handshake_succeeded: bool = false, // 0x01000
                handshake_failed_protocol: bool = false, // 0x02000
                handshake_failed_auth: bool = false, // 0x04000
                _padding_1: u1 = 0, // 0x08000
                pipes_stats: bool = false, // 0x10000
                _padding_2: u47 = 0,
            },
        };
    }
    pub const MonitorError = error{
        ContextInvalid,
        /// Only "inproc" transport can be used for monitoring
        ProtocolNotSupported,
        EndpointInvalid,
        AddressInUse,
        Unexpected,
    };
    pub fn monitor(
        self: *Self,
        endpoint: [:0]const u8,
        event: MonitorVersionedEvent(.v1),
    ) MonitorError!void {
        return switch (zmq.zmq_socket_monitor(self, endpoint.ptr, @bitCast(event))) {
            -1 => switch (errno()) {
                zmq.ETERM => MonitorError.ContextInvalid,
                zmq.EPROTONOSUPPORT => MonitorError.ProtocolNotSupported,
                zmq.EINVAL => MonitorError.EndpointInvalid,
                zmq.EADDRINUSE => MonitorError.AddressInUse,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return MonitorError.Unexpected;
                },
            },
            else => {},
        };
    }

    pub const EventVersion = enum(c_int) { v1 = 1, v2 = 2 };
    pub const MonitorType = enum(c_int) {
        pair = zmq.ZMQ_PAIR,
        @"pub" = zmq.ZMQ_PUB,
        push = zmq.ZMQ_PUSH,
    };
    pub fn monitorVersioned(
        self: *Self,
        comptime version: EventVersion,
        endpoint: [:0]const u8,
        event: MonitorVersionedEvent(version),
        monitor_type: MonitorType,
    ) MonitorError!void {
        return switch (zmq.zmq_socket_monitor_versioned(
            self,
            endpoint.ptr,
            @bitCast(event),
            @intFromEnum(version),
            @intFromEnum(monitor_type),
        )) {
            -1 => switch (errno()) {
                zmq.ETERM => MonitorError.ContextInvalid,
                zmq.EPROTONOSUPPORT => MonitorError.ProtocolNotSupported,
                zmq.EINVAL => MonitorError.EndpointInvalid,
                zmq.EADDRINUSE => MonitorError.AddressInUse,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return MonitorError.Unexpected;
                },
            },
            else => {},
        };
    }

    pub const PipesStatsError = error{
        SocketInvalid,
        MonitorNotEnabled,
        NoConnection,
        Unexpected,
    };
    pub fn pipesStats(self: *Self) PipesStatsError!void {
        return switch (zmq.zmq_socket_monitor_pipes_stats(self)) {
            -1 => switch (errno()) {
                zmq.ENOTSOCK => PipesStatsError.SocketInvalid,
                zmq.EINVAL => PipesStatsError.MonitorNotEnabled,
                zmq.EAGAIN => PipesStatsError.NoConnection,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return PipesStatsError.Unexpected;
                },
            },
            else => {},
        };
    }

    pub const JoinError = error{
        /// group has more than 255 characters or the socket already joined it
        GroupInvalid,
        Unexpected,
    };
    pub fn join(self: *Self, group: [:0]const u8) !void {
        return switch (zmq.zmq_join(self, group)) {
            -1 => switch (errno()) {
                zmq.EINVAL => JoinError.GroupInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return JoinError.Unexpected;
                },
            },
            else => {},
        };
    }
    pub const LeaveError = error{
        /// group has more than 255 characters or the socket has not joined it
        GroupInvalid,
        Unexpected,
    };
    pub fn leave(self: *Self, group: [:0]const u8) !void {
        return switch (zmq.zmq_leave(self, group)) {
            -1 => switch (errno()) {
                zmq.EINVAL => LeaveError.GroupInvalid,
                else => |err| {
                    log("{s}\n", .{strerror(err)});
                    return LeaveError.Unexpected;
                },
            },
            else => {},
        };
    }

    test monitor {
        const t = std.testing;

        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        try t.expectEqual({}, socket.monitor("inproc://#1", .{}));
        try t.expectEqual(Socket.MonitorError.EndpointInvalid, socket.monitor("", .{}));
        try t.expectEqual(Socket.MonitorError.ProtocolNotSupported, socket.monitor("tpc://asdf", .{}));

        socket.pipesStats() catch {};
    }
    test monitorVersioned {
        const t = std.testing;

        var context: *Context = try .init();
        defer context.deinit();

        var socket: *Socket = try .init(context, .pull);
        defer socket.deinit();

        // The following test is unstable due to ZeroMQ can be slow in creating and binding
        // the socket, it should return a AddressInUse error
        _ = socket.monitorVersioned(.v2, "inproc://#1", .{}, .pair) catch {};
        try t.expectEqual(Socket.MonitorError.EndpointInvalid, socket.monitor("", .{}));
        try t.expectEqual(Socket.MonitorError.ProtocolNotSupported, socket.monitor("tpc://asdf", .{}));
        try socket.monitorVersioned(.v2, "inproc://#2", .{}, .pair);

        socket.pipesStats() catch {};
    }
};

test "radio and dish" {
    const t = std.testing;

    var context: *Context = try .init();
    defer context.deinit();

    const dish: *Socket = try .init(context, .dish);
    defer dish.deinit();

    const radio: *Socket = try .init(context, .radio);
    defer radio.deinit();

    try dish.bind("udp://127.0.0.1:10080");
    try radio.connect("udp://127.0.0.1:10080");

    try dish.join("somegroup");

    var msg: Message = try .withSlice("hello");
    defer msg.deinit();
    try msg.setGroup("somegroup");

    try radio.sendMsg(&msg, .{});
    var buffer: [5]u8 = undefined;
    try t.expectEqual(5, try dish.recv(&buffer, .{}));
    try t.expectEqualStrings("hello", &buffer);
}

test "server and client" {
    const t = std.testing;

    var context: *Context = try .init();
    defer context.deinit();

    const server: *Socket = try .init(context, .server);
    defer server.deinit();

    const client: *Socket = try .init(context, .client);
    defer client.deinit();

    try server.bind("inproc://#1");
    try client.connect("inproc://#1");

    var msg: Message = try .withSlice("hello");
    defer msg.deinit();

    try client.sendMsg(&msg, .{});
    var buffer: [5]u8 = undefined;
    try t.expectEqual(5, try server.recv(&buffer, .{}));
    try t.expectEqualStrings("hello", &buffer);
}
