# skein-shell

The shell app for a [skein](https://github.com/shruggr/skein): `run` runs
a bash command in the WASI shell over a tree, and the shell itself — brush,
uutils coreutils and the toolset — ships here as files of the app's tree.
Version **0.1.1**. A skein has no shell of its own: an instance runs
commands once this app is installed (shruggr/skein#83).

## What it is

| box | program | what |
|---|---|---|
| `shell/run` (written `"run"`: a box is relative to the app, shruggr/skein#128) | `run-handler` | `{cmd, tree?, cwd?, env?}` from the owner: a bash command in the shell over a tree (no tree: the `main` head's); replies in the sender's `results` box with `{exitCode, stdout, stderr, tree, replyTo}` |

The shell is this app's `shell` program: a program the kernel runs itself
(skein's `kernel-zig/src/shell.zig`), its modules named in the manifest —
brush and coreutils plus find, xargs, diff, cmp, jq, which, grep, tree,
awk, sed, git, qjs (also `node`) and python (also `python3`, with its
standard library mounted read-only at `/opt/skein/python`). `run-handler`
launches it, and so does the chat app's loop (shruggr/skein-chat) for its
`bash` tool: both find it in the app record at the head `shell/app`.

| file | what |
|---|---|
| `bin/run-handler.wasm` | the `run` handler (Zig, wasm32-wasi, committed; `zig build bin` rewrites it) |
| `bin/brush.wasm`, `bin/coreutils.wasm`, `bin/<tool>.wasm` | the shell's modules (committed; `scripts/build-toolset.sh` rebuilds them) |
| `lib/python314.zip` | python's standard library, a support file |
| `etc/app.json` | the manifest |
| `programs/run-handler/` | the handler's source |
| `toolset/`, `scripts/build-toolset.sh` | the modules' sources, patches and build (`toolset/README.md`) |

## Install it

```
skein-host install https://github.com/shruggr/skein-shell --instance <handle>
```

The install sends the tree, each module and the stdlib as raw blocks (the
largest, coreutils and the stdlib, ~10 MB each: a minute or so on a dev
machine), the program records, the head `shell/app`, and the row `run` from
the owner. Then, from the client (`bin/skein` in skein):

```
bin/skein run --tree <cid> -- 'ls | head -3'
```

The manifest, `etc/app.json` (the modules map shortened, the description
left out):

```json
{
  "kind": "app",
  "name": "shell",
  "version": "0.1.1",
  "programs": {
    "run": "bin/run-handler.wasm",
    "shell": {
      "code": "shell",
      "modules": { "brush": "bin/brush.wasm", "coreutils": "bin/coreutils.wasm", "jq": "bin/jq.wasm",
                   "qjs": "bin/qjs.wasm", "node": "bin/qjs.wasm", "python": "bin/python.wasm", "python3": "bin/python.wasm" },
      "support": {
        "python": { "mount": "/opt/skein/python", "files": { "lib/python314.zip": "lib/python314.zip" },
                    "env": { "PYTHONHOME": "/opt/skein/python", "PYTHONDONTWRITEBYTECODE": "1" } }
      }
    }
  },
  "provides": [
    { "interface": "shell/1", "functions": { "run": { "writes": true,
      "args": { "cmd": "string", "tree?": "cid", "cwd?": "string", "env?": "map" },
      "answer": { "exitCode": "int", "stdout": "string", "stderr": "string", "tree": "cid" } } } }
  ],
  "requires": [],
  "dispatch": [
    { "address": "run", "sender": "$owner", "program": "run" }
  ]
}
```

`programs.shell` is a shell program (skein's docs/APPS.md, "A shell
program"): every name in `modules` is a command, `brush` and `coreutils`
the shell; `support` mounts files for one command only. The install turns
it into the record the kernel runs, each path a raw CID.

## Build and test

Zig 0.16.0 (`mise.toml`).

```
zig build                  # zig-out/bin/run-handler.wasm
zig build bin              # the same, into bin/ (reproducible)
zig build test             # the manifest's checks: every file it names is in the tree, every module a wasm module
scripts/build-toolset.sh   # the shell's modules into bin/, the stdlib into lib/ (needs rustup with wasm32-wasip1, curl, unzip, node; fetches wasi-sdk 34)
```

The Zig build is reproducible; the toolset build is reproducible on the
same machine in the same checkout layout only (`toolset/README.md`).

The behaviour is tested in skein, where the kernel runs these modules: the
shell cases (`kernel-zig/equiv/shell.ts`), git in the VM (`equiv/git.ts`),
`run` through the host (`equiv/corpus.ts`, `boot.ts`, `serve.ts`) and the
npm suite. skein's tests install this app at the commit pinned in its
`src/testapps.ts` (or `$SKEIN_SHELL_DIR`, a checkout).

## Docs

| what | where |
|---|---|
| the toolset: each module's source and patches | `toolset/README.md` |
| a shell program in a manifest; the shell app and the chat app | skein `docs/APPS.md` §6b |
| the shell in the VM, the clock, fuel | skein `docs/VM.md`, `kernel-zig/README.md` |

## Versions

| | |
|---|---|
| this app | 0.1.1 (tag `v0.1.1`) |
| skein-sdk | v0.4.0, by tag tarball and hash in `build.zig.zon` |

0.1.1: the `run` box is `shell/run` — the manifest still writes `"run"`; skein
resolves a mailbox box under the app's name (shruggr/skein#128). Nothing else
changed.

0.1.0 is the split of shruggr/skein-workbench (archived) into this app and
shruggr/skein-chat (shruggr/skein#83): `run` and the whole userland here,
the chat loop there. The history of `run-handler` and the toolset is this
repository's.

## Contributing

Work is tracked in shruggr/skein; start at issue
[#31](https://github.com/shruggr/skein/issues/31). MIT, as skein.
