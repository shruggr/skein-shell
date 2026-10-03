// skein-shell (shruggr/skein#83): the shell app — `run` (a bash command in
// the wasm shell over a tree) and the shell itself: brush, uutils coreutils
// and the toolset (find, xargs, diff, cmp, jq, which, grep, tree, awk, sed,
// git, qjs/node, python/python3). The handler is Zig 0.16.0, wasm32-wasi,
// over the SDK (skein-sdk: `cbor`, `sk`); the toolset's modules are built by
// scripts/build-toolset.sh, not here.
//
//   zig build        → zig-out/bin/run-handler.wasm
//   zig build bin    the same, written to bin/ (the app tree's module; committed)
//   zig build test   the manifest's checks (natively): every file it names is
//                    in the tree, every module a wasm module; run-handler built
//
// The build is reproducible: bin/run-handler.wasm is byte for byte what
// `zig build bin` writes from this tree.
const std = @import("std");

const programs = [_]struct { name: []const u8, root: []const u8 }{
    .{ .name = "run-handler", .root = "programs/run-handler/main.zig" },
};

pub fn build(b: *std.Build) void {
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const bin = b.addUpdateSourceFiles();
    for (programs) |p| {
        const exe = b.addExecutable(.{ .name = p.name, .root_module = module(b, p.root, wasi, .ReleaseSafe, true) });
        b.installArtifact(exe);
        bin.addCopyFileToSource(exe.getEmittedBin(), b.fmt("bin/{s}.wasm", .{p.name}));
    }
    b.step("bin", "write the module into the app tree: bin/run-handler.wasm").dependOn(&bin.step);

    const test_step = b.step("test", "the manifest's checks, natively; run-handler built");
    test_step.dependOn(b.getInstallStep());
    const native = b.standardTargetOptions(.{});
    const manifest = b.addTest(.{ .root_module = b.createModule(.{ .root_source_file = b.path("test/manifest.zig"), .target = native, .optimize = .Debug }) });
    const run = b.addRunArtifact(manifest);
    run.setCwd(b.path("."));
    test_step.dependOn(&run.step);
}

fn module(b: *std.Build, root: []const u8, t: std.Build.ResolvedTarget, o: std.builtin.OptimizeMode, strip: bool) *std.Build.Module {
    const sdk = b.dependency("skein_sdk", .{ .target = t, .optimize = o, .wallet = false });
    return b.createModule(.{
        .root_source_file = b.path(root),
        .target = t,
        .optimize = o,
        .strip = strip,
        .imports = &.{
            .{ .name = "cbor", .module = sdk.module("cbor") },
            .{ .name = "sk", .module = sdk.module("sk") },
        },
    });
}
