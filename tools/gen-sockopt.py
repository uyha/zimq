from dataclasses import dataclass
from urllib import request

from parsel import Selector


@dataclass
class Option:
    name: str
    macro: str
    value_type: str
    comment: str | None = None


deprecated = {
    "ZMQ_CONNECT_RID",
    "ZMQ_IDENTITY",
    "ZMQ_ROUTER_RAW",
    "ZMQ_TCP_ACCEPT_FILTER",
    "ZMQ_IPC_FILTER_GID",
    "ZMQ_IPC_FILTER_PID",
    "ZMQ_IPC_FILTER_UID",
    "ZMQ_IPV4ONLY",
}

headers = {"User-Agent": "Mozilla/5.0"}

set_url = "https://libzmq.readthedocs.io/en/latest/zmq_setsockopt.html"
with request.urlopen(request.Request(set_url, headers=headers)) as resp:
    set_sel = Selector(resp.read().decode())


set_options: list[Option] = []
get_options: list[Option] = []

for option in set_sel.xpath("//div[@class='sect2']"):
    name = option.xpath("h3/text()").get()
    assert name is not None
    name = name.split(":")[0].strip()

    assert name.startswith("ZMQ_")
    if name in deprecated:
        continue

    zig_name = f"{name.removeprefix("ZMQ_").lower()}"
    macro = f"zmq.{name}"

    try:
        value_type, value_unit, *_ = option.xpath("./div[@class='hdlist']//tr")
    except ValueError:
        continue

    assert (
        "".join(value_type.xpath("./td[1]/text()").getall()).strip()
        == "Option value type"
    )
    unit_label = "".join(value_unit.xpath("./td[1]/text()").getall()).strip()
    assert unit_label == "Option value unit" or unit_label == "Option value size"

    value_type = "".join(value_type.xpath("./td[2]//text()").getall()).strip()
    value_unit = "".join(value_unit.xpath("./td[2]//text()").getall()).strip()

    comment = value_unit
    match ((value_type, value_unit, name)):
        case (_, _, "ZMQ_RECONNECT_STOP"):
            comment = None
            zig_type = "ReconnectStop"
        case (_, _, "ZMQ_ROUTER_NOTIFY"):
            comment = None
            zig_type = "RouterNotify"
        case (_, _, "ZMQ_NORM_MODE"):
            comment = None
            zig_type = "NormMode"
        case (_, _, name) if name in {
            "ZMQ_GSSAPI_SERVICE_PRINCIPAL_NAMETYPE",
            "ZMQ_GSSAPI_PRINCIPAL_NAMETYPE",
        }:
            comment = None
            zig_type = "PrincipalNameType"
        case ("int", "0, 1", _):
            comment = None
            zig_type = "bool"
        case ("int", "0,1", _):
            comment = None
            zig_type = "bool"
        case ("int", "boolean", _):
            comment = None
            zig_type = "bool"
        case ("int", _, _):
            zig_type = "c_int"
        case ("uint64_t", _, _):
            zig_type = "u64"
        case ("int64_t", _, _):
            zig_type = "i64"
        case ("character string", _, _):
            zig_type = "[:0]const u8"
        case ("binary data", _, _):
            zig_type = "[]const u8"
        case ("binary data or Z85 text string", _, _):
            comment = "32 or 41 characters"
            zig_type = "[]const u8"
        case _:
            print(value_type, value_unit)
            raise NotImplementedError()

    if comment is not None:
        comment = comment.replace("N/A", "").replace("⇐", "<=").strip()

        if comment == "(bitmap)" or len(comment) == 0:
            comment = None

    set_options.append(
        Option(name=zig_name, macro=macro, value_type=zig_type, comment=comment)
    )

get_url = "https://libzmq.readthedocs.io/en/latest/zmq_getsockopt.html"
with request.urlopen(request.Request(get_url, headers=headers)) as resp:
    get_sel = Selector(resp.read().decode())

for option in get_sel.xpath("//div[@class='sect2']"):
    name = option.xpath("h3/text()").get()
    assert name is not None
    name = name.split(":")[0].strip()

    assert name.startswith("ZMQ_")
    if name in deprecated:
        continue

    zig_name = f"{name.removeprefix("ZMQ_").lower()}"
    macro = f"zmq.{name}"

    try:
        value_type, value_unit, *_ = option.xpath("./div[@class='hdlist']//tr")
    except ValueError:
        continue

    assert (
        "".join(value_type.xpath("./td[1]/text()").getall()).strip()
        == "Option value type"
    )
    unit_label = "".join(value_unit.xpath("./td[1]/text()").getall()).strip()
    assert unit_label == "Option value unit" or unit_label == "Option value size"

    value_type = "".join(value_type.xpath("./td[2]//text()").getall()).strip()
    value_unit = "".join(value_unit.xpath("./td[2]//text()").getall()).strip()

    comment = value_unit
    match ((value_type, value_unit, name)):
        case (_, _, "ZMQ_RECONNECT_STOP"):
            comment = None
            zig_type = "ReconnectStop"
        case (_, _, "ZMQ_ROUTER_NOTIFY"):
            comment = None
            zig_type = "RouterNotify"
        case (_, _, "ZMQ_NORM_MODE"):
            comment = None
            zig_type = "NormMode"
        case (_, _, "ZMQ_MECHANISM"):
            comment = None
            zig_type = "Mechanism"
        case (_, _, name) if name in {
            "ZMQ_GSSAPI_SERVICE_PRINCIPAL_NAMETYPE",
            "ZMQ_GSSAPI_PRINCIPAL_NAMETYPE",
        }:
            comment = None
            zig_type = "PrincipalNameType"
        case (_, _, "ZMQ_USE_FD"):
            comment = None
            zig_type = "posix.socket_t"
        case (_, _, "ZMQ_TYPE"):
            comment = None
            zig_type = "Type"
        case ("int", "0, 1", _):
            comment = None
            zig_type = "bool"
        case ("int", "0,1", _):
            comment = None
            zig_type = "bool"
        case ("int", "boolean", _):
            comment = None
            zig_type = "bool"
        case ("int", _, _):
            zig_type = "c_int"
        case ("uint64_t", _, _):
            zig_type = "u64"
        case ("int64_t", _, _):
            zig_type = "i64"
        case ("character string", _, _):
            zig_type = "[:0]u8"
        case ("NULL-terminated character string", _, _):
            zig_type = "[:0]u8"
        case ("binary data", _, _):
            zig_type = "[]u8"
            if name == "ZMQ_ROUTING_ID":
                comment = ">1, <=255 bytes"
        case ("binary data or Z85 text string", _, _):
            comment = "32 or 41 characters"
            zig_type = "[]u8"
        case ("int on POSIX systems, SOCKET on Windows", _, _):
            zig_type = "posix.socket_t"
        case _:
            print(value_type, value_unit, name)
            raise NotImplementedError()

    if comment is not None:
        comment = comment.replace("N/A", "").replace("⇐", "<=").strip()

        if comment == "(bitmap)" or len(comment) == 0:
            comment = None

    get_options.append(
        Option(name=zig_name, macro=macro, value_type=zig_type, comment=comment)
    )
    if name == "ZMQ_USE_FD":
        get_options.append(
            Option(
                name="priority",
                macro="zmq.ZMQ_PRIORITY",
                value_type="c_int",
                comment=">0",
            )
        )


print("// Auto generated, change by updating tools/gen-ctxopt.py instead")
print("""const zmq = @import("libzmq");""")
print("""const posix = @import("std").posix;""")
print("""pub const Type = @import("type.zig").Type;""")
print()
print(
    """
pub const Mechanism = enum(c_int) {
    null = zmq.ZMQ_NULL,
    plain = zmq.ZMQ_PLAIN,
    curve = zmq.ZMQ_CURVE,
    gssapi = zmq.ZMQ_GSSAPI,
};""".strip()
)
print(
    """
pub const ReconnectStop = packed struct(c_int) {
    conn_refused: bool = false,
    handshake_failed: bool = false,
    after_disconnect: bool = false,
    _padding: u29 = 0,
};""".strip()
)
print(
    """
pub const RouterNotify = packed struct(c_int) {
    connect: bool = false,
    disconnect: bool = false,
    _padding: u30 = 0,
};""".strip()
)
print(
    """
pub const NormMode = enum(c_int) {
    fixed = zmq.ZMQ_NORM_FIXED,
    cc = zmq.ZMQ_NORM_CC,
    ccl = zmq.ZMQ_NORM_CCL,
    cce = zmq.ZMQ_NORM_CCE,
    ecnonly = zmq.ZMQ_NORM_CCE_ECNONLY,
};""".strip()
)
print(
    """
pub const PrincipalNameType = enum(c_int) {
    hostbased = zmq.ZMQ_GSSAPI_NT_HOSTBASED,
    user_name = zmq.ZMQ_GSSAPI_NT_USER_NAME,
    unparsed = zmq.ZMQ_GSSAPI_NT_KRB5_PRINCIPAL,
};""".strip()
)
print()
print("pub const SetOption = enum(c_int) {")
for opt in set_options:
    print(f"    {opt.name} = {opt.macro},")
print("};")
print("pub fn SetOptionType(option: SetOption) type {")
print("    return switch (option) {")
for opt in set_options:
    print(
        f"        .{opt.name} => {opt.value_type},{f' // {opt.comment}' if opt.comment is not None else ''}"
    )
print("    };")
print("}")
print()
print("pub const GetOption = enum(c_int) {")
for opt in get_options:
    print(f"    {opt.name} = {opt.macro},")
print("};")
print("pub fn GetOptionType(option: GetOption) type {")
print("    return switch (option) {")
for opt in get_options:
    print(
        f"        .{opt.name} => {opt.value_type},{f' // {opt.comment}' if opt.comment is not None else ''}"
    )
print("    };")
print("}")
