// The manifest's checks (`zig build test`, run from the tree's root): every
// file etc/app.json names is in the tree — a program's module, each of the
// shell program's modules and support files — and every module is a WASI
// preview1 module. skein's install (src/host/manifest.ts) checks the same
// before it sends anything; this catches a rename here first.
const std = @import("std");

fn read(a: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, a, .limited(1 << 30)) catch |e| {
        std.debug.print("etc/app.json names {s}, which is not in the tree: {s}\n", .{ path, @errorName(e) });
        return e;
    };
}

fn expectModule(a: std.mem.Allocator, path: []const u8) !void {
    const b = try read(a, path);
    if (!std.mem.startsWith(u8, b, "\x00asm\x01\x00\x00\x00")) {
        std.debug.print("{s}: not a wasm module\n", .{path});
        return error.NotAModule;
    }
}

test "every file the manifest names is in the tree" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const m = try std.json.parseFromSliceLeaky(std.json.Value, a, try read(a, "etc/app.json"), .{});
    try std.testing.expectEqualStrings("app", m.object.get("kind").?.string);
    try std.testing.expectEqualStrings("shell", m.object.get("name").?.string);
    const progs = m.object.get("programs").?.object;
    try expectModule(a, progs.get("run").?.string);
    const shell = progs.get("shell").?.object;
    try std.testing.expectEqualStrings("shell", shell.get("code").?.string);
    const mods = shell.get("modules").?.object;
    // brush and coreutils are the shell; every other name is a command.
    try std.testing.expect(mods.get("brush") != null and mods.get("coreutils") != null);
    var it = mods.iterator();
    while (it.next()) |e| try expectModule(a, e.value_ptr.string);
    var sit = shell.get("support").?.object.iterator();
    while (sit.next()) |s| {
        try std.testing.expect(mods.get(s.key_ptr.*) != null);
        var fit = s.value_ptr.object.get("files").?.object.iterator();
        while (fit.next()) |f| _ = try read(a, f.value_ptr.string);
    }
    // Every row's program is a role.
    for (m.object.get("dispatch").?.array.items) |r| try std.testing.expect(progs.get(r.object.get("program").?.string) != null);
}
