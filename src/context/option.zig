// Auto generated, change by updating tools/gen-ctxopt.py instead
const zmq = @import("zmq");

pub const SetOption = enum(c_int) {
    blocky = zmq.ZMQ_BLOCKY,
    io_threads = zmq.ZMQ_IO_THREADS,
    thread_sched_policy = zmq.ZMQ_THREAD_SCHED_POLICY,
    thread_priority = zmq.ZMQ_THREAD_PRIORITY,
    thread_affinity_cpu_add = zmq.ZMQ_THREAD_AFFINITY_CPU_ADD,
    thread_affinity_cpu_remove = zmq.ZMQ_THREAD_AFFINITY_CPU_REMOVE,
    thread_name_prefix = zmq.ZMQ_THREAD_NAME_PREFIX,
    max_msgsz = zmq.ZMQ_MAX_MSGSZ,
    zero_copy_recv = zmq.ZMQ_ZERO_COPY_RECV,
    max_sockets = zmq.ZMQ_MAX_SOCKETS,
    ipv6 = zmq.ZMQ_IPV6,
};
pub fn SetOptionType(option: SetOption) type {
    return switch (option) {
        .blocky, .zero_copy_recv, .ipv6 => bool,
        .thread_name_prefix => [:0]const u8,
        else => c_int,
    };
}

pub const GetOption = enum(c_int) {
    io_threads = zmq.ZMQ_IO_THREADS,
    max_sockets = zmq.ZMQ_MAX_SOCKETS,
    max_msgsz = zmq.ZMQ_MAX_MSGSZ,
    zero_copy_recv = zmq.ZMQ_ZERO_COPY_RECV,
    socket_limit = zmq.ZMQ_SOCKET_LIMIT,
    ipv6 = zmq.ZMQ_IPV6,
    blocky = zmq.ZMQ_BLOCKY,
    thread_sched_policy = zmq.ZMQ_THREAD_SCHED_POLICY,
    thread_name_prefix = zmq.ZMQ_THREAD_NAME_PREFIX,
    msg_t_size = zmq.ZMQ_MSG_T_SIZE,
};
pub fn GetOptionType(option: GetOption) type {
    return switch (option) {
        .blocky, .zero_copy_recv, .ipv6 => bool,
        .thread_name_prefix => [:0]u8,
        else => c_int,
    };
}
