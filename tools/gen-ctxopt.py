from urllib import request

from parsel import Selector

print("// Auto generated, change by updating tools/gen-ctxopt.py instead")
print("""const zmq = @import("libzmq");""")
print()

# -------------------------------------Set Options-------------------------------------
set_types = {
    "bool": ["blocky", "zero_copy_recv", "ipv6"],
    "[:0]const u8": ["thread_name_prefix"],
}

headers = {"User-Agent": "Mozilla/5.0"}

url = "https://libzmq.readthedocs.io/en/latest/zmq_ctx_set.html"
with request.urlopen(request.Request(url, headers=headers)) as resp:
    sel = Selector(resp.read().decode())


print("pub const SetOption = enum(c_int) {")
for text in sel.xpath("//div[@class='sect2']/h3/text()"):
    raw = text.get()
    assert raw is not None
    assert isinstance(raw, str)

    name, _ = raw.split(":")
    name = name.strip()
    assert name.startswith("ZMQ_")
    zig = name.removeprefix("ZMQ_").lower()
    print(f"    {zig} = zmq.{name},")

print("};")
print("pub fn SetOptionType(option: SetOption) type {")
print("    return switch (option) {")
for t, opts in set_types.items():
    print(f"        {', '.join(f'.{opt}' for opt in opts)} => {t},")
print("        else => c_int,")
print("    };")
print("}")
print("")

# -------------------------------------Get Options-------------------------------------

get_types = {
    "bool": ["blocky", "zero_copy_recv", "ipv6"],
    "[:0]u8": ["thread_name_prefix"],
}
url = "https://libzmq.readthedocs.io/en/latest/zmq_ctx_get.html"
with request.urlopen(request.Request(url, headers=headers)) as resp:
    sel = Selector(resp.read().decode())
print("pub const GetOption = enum(c_int) {")
for text in sel.xpath("//div[@class='sect2']/h3/text()"):
    raw = text.get()
    assert raw is not None
    assert isinstance(raw, str)

    name, _ = raw.split(":")
    name = name.strip()
    assert name.startswith("ZMQ_")
    zig = name.removeprefix("ZMQ_").lower()
    print(f"    {zig} = zmq.{name},")

print("};")
print("pub fn GetOptionType(option: GetOption) type {")
print("    return switch (option) {")
for t, opts in get_types.items():
    print(f"        {', '.join(f'.{opt}' for opt in opts)} => {t},")
print("        else => c_int,")
print("    };")
print("}")
