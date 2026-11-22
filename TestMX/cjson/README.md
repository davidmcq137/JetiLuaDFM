# Lua CJSON 2.1.0, for TestMitter

JETI's `json` library is based on Lua CJSON; its doc says so. The emulator
(6.06) behaves exactly like stock Lua CJSON 2.1.0 with the default settings:
see `JsonProbe/jsonprobe-emu606.txt`. Examples:

- arrays with holes are padded with `null`: `{[2] = 5}` encodes as `[null,5]`
- an empty table encodes as `{}`
- `null` decodes to a lightuserdata, which stays in its slot
- `NULL` is invalid JSON

So TestMitter uses the real library, unchanged, rather than a Lua imitation.
`TestMX/build.sh` compiles these files into `testmx_c.so`, and
`testmx.lua` opens them with `luaopen_cjson`.

Source: https://github.com/mpx/lua-cjson, tag 2.1.0
(commit 4bc5e917c8cd5fc2f6b217512ef530007529322f). Files copied unchanged:
`lua_cjson.c`, `strbuf.c`, `strbuf.h`, `fpconv.c`, `fpconv.h`, `LICENSE` (MIT).
