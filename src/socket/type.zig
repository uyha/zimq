const zmq = @import("libzmq");

pub const Type = enum(c_int) {
    req = zmq.ZMQ_REQ,
    rep = zmq.ZMQ_REP,
    dealer = zmq.ZMQ_DEALER,
    router = zmq.ZMQ_ROUTER,
    @"pub" = zmq.ZMQ_PUB,
    sub = zmq.ZMQ_SUB,
    xpub = zmq.ZMQ_XPUB,
    xsub = zmq.ZMQ_XSUB,
    push = zmq.ZMQ_PUSH,
    pull = zmq.ZMQ_PULL,
    pair = zmq.ZMQ_PAIR,
    peer = zmq.ZMQ_PEER,
    radio = zmq.ZMQ_RADIO,
    dish = zmq.ZMQ_DISH,
};
