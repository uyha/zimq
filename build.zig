const std = @import("std");
const Build = std.Build;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const poller = b.option(Poller, "poller",
        \\Choose polling system [default=poll].
    ) orelse .poll;
    const draft = b.option(bool, "draft",
        \\Include the draft API
    ) orelse true;
    const use_radix_tree = b.option(
        bool,
        "use-radix-tree",
        "Use radix tree implementation to manage subscriptions",
    ) orelse draft;
    const strip = b.option(
        bool,
        "strip",
        "Omit debug symbols",
    ) orelse (optimize != .Debug);

    const options: Options = .{
        .poller = poller,
        .draft = draft,
        .use_radix_tree = use_radix_tree,
    };

    const libzmq = buildLibzmq(
        b,
        target,
        optimize,
        strip,
        options,
    );

    const upstream = b.dependency("libzmq", .{});
    const translate = b.addTranslateC(.{
        .root_source_file = upstream.path(
            b.pathJoin(&.{ "include", "zmq.h" }),
        ),
        .target = target,
        .optimize = optimize,
    });
    if (options.draft) {
        translate.defineCMacro("ZMQ_BUILD_DRAFT_API", "");
    }
    inline for (@typeInfo(@TypeOf(shared_values)).@"struct".fields) |field| {
        translate.defineCMacro(field.name, "");
    }
    const libzmq_module = b.createModule(.{
        .root_source_file = translate.getOutput(),
        .target = target,
        .optimize = optimize,
    });
    const zimq = b.addModule(
        "zimq",
        .{
            .root_source_file = b.path(
                b.pathJoin(&.{ "src", "root.zig" }),
            ),
            .target = target,
            .optimize = optimize,
            .strip = strip,
        },
    );
    zimq.addImport("libzmq", libzmq_module);
    zimq.linkLibrary(libzmq);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zimq",
        .root_module = zimq,
    });
    b.installArtifact(lib);

    const tests = b.addTest(.{
        .name = "zimq",
        .root_module = zimq,
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step(
        "zimq-test",
        "zmq module test",
    );
    test_step.dependOn(&run_tests.step);

    const docs = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = lib.getEmittedDocs(),
    });
    const docs_step = b.step("zimq-docs", "Emit documentation");
    docs_step.dependOn(&docs.step);

    const format = b.addFmt(.{
        .check = true,
        .paths = &.{
            "src/",
            "build.zig",
            "build.zig.zon",
            "example.zig",
        },
    });
    const format_step = b.step("zimq-fmt", "Format project");
    format_step.dependOn(&format.step);

    const all = b.step("zimq-all", "Run all steps");
    all.dependOn(test_step);
    all.dependOn(docs_step);
    all.dependOn(format_step);

    const zimq_example = b.addExecutable(.{
        .name = "zimq-example",
        .root_source_file = b.path("example.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    b.installArtifact(zimq_example);
    zimq_example.root_module.addImport("zimq", zimq);
    const run_zimq_example = b.addRunArtifact(zimq_example);

    const run_zimq_example_step = b.step(
        "zimq-example",
        "Run zimq example",
    );
    run_zimq_example_step.dependOn(&run_zimq_example.step);
}

const Poller = enum { poll, select };
const Options = struct {
    poller: Poller,
    draft: bool,
    use_radix_tree: bool,
};

const shared_values = .{
    ._REENTRANT = {},
    ._THREAD_SAFE = {},

    .ZMQ_CUSTOM_PLATFORM_HPP = {},
    .ZMQ_USE_CV_IMPL_STL11 = {}, // LLVM for sure has std::condition_variable
    .ZMQ_HAVE_NOEXCEPT = {}, // LLVM for sure supports `noexcept`
};
const zmq_source_files = [_][]const u8{
    // "ws_address.cpp",
    // "ws_connecter.cpp",
    // "ws_decoder.cpp",
    // "ws_encoder.cpp",
    // "ws_engine.cpp",
    // "ws_listener.cpp",
    // "wss_address.cpp",
    // "wss_engine.cpp",
    "precompiled.cpp",
    "address.cpp",
    "channel.cpp",
    "client.cpp",
    "clock.cpp",
    "ctx.cpp",
    "curve_mechanism_base.cpp",
    "curve_client.cpp",
    "curve_server.cpp",
    "dealer.cpp",
    "devpoll.cpp",
    "dgram.cpp",
    "dist.cpp",
    "endpoint.cpp",
    "epoll.cpp",
    "err.cpp",
    "fq.cpp",
    "io_object.cpp",
    "io_thread.cpp",
    "ip.cpp",
    "ipc_address.cpp",
    "ipc_connecter.cpp",
    "ipc_listener.cpp",
    "kqueue.cpp",
    "lb.cpp",
    "mailbox.cpp",
    "mailbox_safe.cpp",
    "mechanism.cpp",
    "mechanism_base.cpp",
    "metadata.cpp",
    "msg.cpp",
    "mtrie.cpp",
    "norm_engine.cpp",
    "object.cpp",
    "options.cpp",
    "own.cpp",
    "null_mechanism.cpp",
    "pair.cpp",
    "peer.cpp",
    "pgm_receiver.cpp",
    "pgm_sender.cpp",
    "pgm_socket.cpp",
    "pipe.cpp",
    "plain_client.cpp",
    "plain_server.cpp",
    "poll.cpp",
    "poller_base.cpp",
    "polling_util.cpp",
    "pollset.cpp",
    "proxy.cpp",
    "pub.cpp",
    "pull.cpp",
    "push.cpp",
    "random.cpp",
    "raw_encoder.cpp",
    "raw_decoder.cpp",
    "raw_engine.cpp",
    "reaper.cpp",
    "rep.cpp",
    "req.cpp",
    "router.cpp",
    "select.cpp",
    "server.cpp",
    "session_base.cpp",
    "signaler.cpp",
    "socket_base.cpp",
    "socks.cpp",
    "socks_connecter.cpp",
    "stream.cpp",
    "stream_engine_base.cpp",
    "sub.cpp",
    "tcp.cpp",
    "tcp_address.cpp",
    "tcp_connecter.cpp",
    "tcp_listener.cpp",
    "thread.cpp",
    "trie.cpp",
    "radix_tree.cpp",
    "v1_decoder.cpp",
    "v1_encoder.cpp",
    "v2_decoder.cpp",
    "v2_encoder.cpp",
    "v3_1_encoder.cpp",
    "xpub.cpp",
    "xsub.cpp",
    "zmq.cpp",
    "zmq_utils.cpp",
    "decoder_allocators.cpp",
    "socket_poller.cpp",
    "timers.cpp",
    "radio.cpp",
    "dish.cpp",
    "udp_engine.cpp",
    "udp_address.cpp",
    "scatter.cpp",
    "gather.cpp",
    "ip_resolver.cpp",
    "zap_client.cpp",
    "zmtp_engine.cpp",
    "stream_connecter_base.cpp",
    "stream_listener_base.cpp",
    "tipc_address.cpp",
    "tipc_connecter.cpp",
    "tipc_listener.cpp",
};

const linux_values = .{
    // `epoll_create` exits in `sys/epoll.h` and is preferred by the build script
    .ZMQ_IOTHREAD_POLLER_USE_EPOLL = 1,
    // `epoll_create1` exists in `sys/epoll.h`
    .ZMQ_IOTHREAD_POLLER_USE_EPOLL_CLOEXEC = {},
    // `posix_memalign` exists in `stdlib.h`
    .HAVE_POSIX_MEMALIGN = {},
    // `pselect` exists in `sys/select.h`
    .ZMQ_HAVE_PPOLL = {},
    // `fork` exists in `unistd.h`
    .HAVE_FORK = {},
    // `clock_gettime` exists in `time.h`
    .HAVE_CLOCK_GETTIME = {},
    // `gethrtime` does not exists in `sys/time.h`
    // `mkdtemp` exists in `"stdlib.h;unistd.h"`
    .HAVE_MKDTEMP = {},
    // `sys/uio.h` exists
    .ZMQ_HAVE_UIO = {},
    // `sys/eventfd.h` exists
    .ZMQ_HAVE_EVENTFD = {},
    // `EFD_CLOEXEC` defined by `sys/eventfd.h`
    // Linux >= 2.6.27 should have it defined
    .ZMQ_HAVE_EVENTFD_CLOEXEC = {},
    // `ifaddrs.h` exists
    .ZMQ_HAVE_IFADDRS = {},
    // `SO_BINDTODEVICE` defined by `sys/socket.h`
    // Linux >= 2.0.30 should have it defined
    .ZMQ_HAVE_SO_BINDTODEVICE = {},

    // `SO_PEERCRED` exits in `sys/socket.h`
    .ZMQ_HAVE_SO_PEERCRED = {},
    // `LOCAL_PEERCRED` does not exits in `sys/socket.h`
    .ZMQ_HAVE_LOCAL_PEERCRED = null,
    // `SO_BUSY_POLL` exits in `sys/socket.h`
    .ZMQ_HAVE_BUSY_POLL = {},

    // `O_CLOEXEC` defined by `fcntl.h`
    // Linux >= 2.6.23 should have it defined
    .ZMQ_HAVE_O_CLOEXEC = {},

    // `SOCK_CLOEXEC` defined by `sys/socket.h`
    // Linux >= 2.6.27 should have it defined
    .ZMQ_HAVE_SOCK_CLOEXEC = {},
    // `SO_KEEPALIVE` defined by `sys/socket.h`
    .ZMQ_HAVE_SO_KEEPALIVE = {},
    // `SO_PRIORITY` defined by `sys/socket.h`
    .ZMQ_HAVE_SO_PRIORITY = {},
    // `TCP_KEEPCNT` defined by `netinet/tcp.h`
    // Linux >= 2.4 should have it defined
    .ZMQ_HAVE_TCP_KEEPCNT = {},
    // `TCP_KEEPIDLE` defined by `netinet/tcp.h`
    // Linux >= 2.4 should have it defined
    .ZMQ_HAVE_TCP_KEEPIDLE = {},
    // `TCP_KEEPINTVL` defined by `netinet/tcp.h`
    // Linux >= 2.4 should have it defined
    .ZMQ_HAVE_TCP_KEEPINTVL = {},
    // `TCP_KEEPALIVE` not defined by `netinet/tcp.h`
    .ZMQ_HAVE_TCP_KEEPALIVE = null,
    // only `pthread_setname_np` accepting 2 parameters is defined in `pthread.h`
    .ZMQ_HAVE_PTHREAD_SETNAME_1 = null,
    .ZMQ_HAVE_PTHREAD_SETNAME_2 = {},
    .ZMQ_HAVE_PTHREAD_SETNAME_3 = null,
    // `pthread_set_name_np` does not exist in `pthread.h`
    .ZMQ_HAVE_PTHREAD_SET_NAME = null,
    // `pthread_setaffinity_np` exists in `pthread.h`
    .ZMQ_HAVE_PTHREAD_SET_AFFINITY = {},
    // `accept4` exists in `sys/socket.h`
    .HAVE_ACCEPT4 = {},
    // `strnlen` exists in `string.h`
    .HAVE_STRNLEN = {},

    // Linux does indeed have IPC and `struct sockaddr_un`
    .ZMQ_HAVE_IPC = {},
    .ZMQ_HAVE_STRUCT_SOCKADDR_UN = {},

    // TODO: Return to ZMQ_USE_BUILTIN_SHA1
    // TODO: Return to ZMQ_USE_NSS
    // TODO: Return to ZMQ_HAVE_WS
    // TODO: Return to ZMQ_HAVE_WSS
    // Linux supports TIPC
    .ZMQ_HAVE_TIPC = {},

    // TODO: Add an option for enabling OpenPGM
    // TODO: Add an option for enabling NORM
    // TODO: Add an option for enabling VMCI

    // TODO: Add an option for enabling CURVE
    // TODO: Add an option for using libsodium
    // TODO: Add an option for using libgssapi_krb5
    // TODO: Add an option for enabling TLS and find a way to find and link GnuTLS

    // `if_nametoindex` exits in `net/if.h`
    .HAVE_IF_NAMETOINDEX = {},
};
const gnu_libc_values = .{
    // `strlcpy` does not exit in `string.h`
    .ZMQ_HAVE_STRLCPY = null,
};
const musl_libc_values = .{
    // `strlcpy` exits in `string.h`
    .ZMQ_HAVE_STRLCPY = {},
};

fn addPlatformValues(
    config_header: *Build.Step.ConfigHeader,
    target: Build.ResolvedTarget,
    options: Options,
) void {
    config_header.addValues(shared_values);
    config_header.addValues(.{
        // TODO: Seems to be wrong when compared with `getconf LEVEL1_DCACHE_LINESIZE`
        .ZMQ_CACHELINE_SIZE = std.atomic.cacheLineForCpu(target.result.cpu),
    });

    switch (options.poller) {
        .poll => config_header.addValues(.{ .ZMQ_POLL_BASED_ON_POLL = 1 }),
        .select => config_header.addValues(.{ .ZMQ_POLL_BASED_ON_SELECT = 1 }),
    }

    if (options.use_radix_tree) {
        config_header.addValues(.{ .ZMQ_USE_RADIX_TREE = {} });
    }

    switch (target.result.os.tag) {
        .linux => {
            config_header.addValues(linux_values);
            if (target.result.isGnuLibC()) {
                config_header.addValues(gnu_libc_values);

                // glibc 2.38 introduces `strlcpy`
                const version_range = target.result.os.versionRange();
                const @"at_least_2.38" = version_range.linux.isAtLeast(
                    .{ .major = 2, .minor = 38, .patch = 0 },
                ) orelse unreachable;
                if (@"at_least_2.38") {
                    config_header.addValues(.{
                        .ZMQ_HAVE_STRLCPY = {},
                    });
                }
            }
            if (target.result.isMuslLibC()) {
                config_header.addValues(musl_libc_values);
            }
        },
        else => {},
    }
}

fn buildLibzmq(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    strip: bool,
    options: Options,
) *std.Build.Step.Compile {
    const upstream = b.dependency("libzmq", .{});

    var platform = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path(
            b.pathJoin(&.{ "builds", "cmake", "platform.hpp.in" }),
        ) },
        .include_path = "platform.hpp",
    }, .{});
    // TODO: Support all the platforms that ZeroMQ supports
    switch (target.result.os.tag) {
        .linux => {},
        else => |tag| {
            const not_supported = b.addFail(b.fmt(
                "{s} is not supported",
                .{@tagName(tag)},
            ));
            platform.step.dependOn(&not_supported.step);
        },
    }
    addPlatformValues(platform, target, options);

    const library = b.addStaticLibrary(.{
        .name = "zmq",
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    library.linkLibC();
    library.linkLibCpp();

    library.root_module.addIncludePath(platform.getOutput().dirname());
    if (options.draft) {
        library.root_module.addCMacro("ZMQ_BUILD_DRAFT_API", "");
    }
    inline for (@typeInfo(@TypeOf(shared_values)).@"struct".fields) |field| {
        library.root_module.addCMacro(field.name, "");
    }
    library.root_module.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &zmq_source_files,
    });

    return library;
}
