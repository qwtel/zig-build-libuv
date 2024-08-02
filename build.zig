const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "uv",
        .target = target,
        .optimize = optimize,
    });

    // Include dirs
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("src"));

    const result = target.result;
    const os = result.os;

    var uv_sources = std.ArrayList([]const u8).init(b.allocator);
    var uv_cflags = std.ArrayList([]const u8).init(b.allocator);
    defer uv_sources.deinit();
    defer uv_cflags.deinit();

    // TODO: add lint flags from cmakelist.txt?
    try uv_cflags.appendSlice(&.{
        "-fno-strict-aliasing",
    });

    try uv_sources.appendSlice(&.{
        "src/fs-poll.c",
        "src/idna.c",
        "src/inet.c",
        "src/random.c",
        "src/strscpy.c",
        "src/strtok.c",
        "src/thread-common.c",
        "src/threadpool.c",
        "src/timer.c",
        "src/uv-common.c",
        "src/uv-data-getter-setters.c",
        "src/version.c",
    });

    // Links
    if (result.os.tag == .windows) {
        lib.defineCMacro("WIN32_LEAN_AND_MEAN", "1");
        lib.defineCMacro("_WIN32_WINNT", "0x0602");
        lib.defineCMacro("_CRT_DECLARE_NONSTDC_NAMES", "0");

        lib.linkSystemLibrary("psapi");
        lib.linkSystemLibrary("user32");
        lib.linkSystemLibrary("advapi32");
        lib.linkSystemLibrary("iphlpapi");
        lib.linkSystemLibrary("userenv");
        lib.linkSystemLibrary("ws2_32");
        lib.linkSystemLibrary("dbghelp");
        lib.linkSystemLibrary("ole32");
        lib.linkSystemLibrary("shell32");

        try uv_sources.appendSlice(&.{
            "src/win/async.c",
            "src/win/core.c",
            "src/win/detect-wakeup.c",
            "src/win/dl.c",
            "src/win/error.c",
            "src/win/fs.c",
            "src/win/fs-event.c",
            "src/win/getaddrinfo.c",
            "src/win/getnameinfo.c",
            "src/win/handle.c",
            "src/win/loop-watcher.c",
            "src/win/pipe.c",
            "src/win/thread.c",
            "src/win/poll.c",
            "src/win/process.c",
            "src/win/process-stdio.c",
            "src/win/signal.c",
            "src/win/snprintf.c",
            "src/win/stream.c",
            "src/win/tcp.c",
            "src/win/tty.c",
            "src/win/udp.c",
            "src/win/util.c",
            "src/win/winapi.c",
            "src/win/winsock.c",
        });
    } else {
        lib.defineCMacro("_FILE_OFFSET_BITS", "64");
        lib.defineCMacro("_LARGEFILE_SOURCE", "1");
        if (!result.isAndroid()) {
            lib.linkSystemLibrary("pthread");
        }

        try uv_sources.appendSlice(&.{
            "src/unix/async.c",
            "src/unix/core.c",
            "src/unix/dl.c",
            "src/unix/fs.c",
            "src/unix/getaddrinfo.c",
            "src/unix/getnameinfo.c",
            "src/unix/loop-watcher.c",
            "src/unix/loop.c",
            "src/unix/pipe.c",
            "src/unix/poll.c",
            "src/unix/process.c",
            "src/unix/random-devurandom.c",
            "src/unix/signal.c",
            "src/unix/stream.c",
            "src/unix/tcp.c",
            "src/unix/thread.c",
            "src/unix/tty.c",
            "src/unix/udp.c",
        });
    }

    if (result.isAndroid()) {
        lib.defineCMacro("_GNU_SOURCE", "1");
        lib.linkSystemLibrary("dl");
        try uv_sources.appendSlice(&.{
            "src/unix/linux.c",
            "src/unix/procfs-exepath.c",
            "src/unix/random-getentropy.c",
            "src/unix/random-getrandom.c",
            "src/unix/random-sysctl-linux.c",
        });
    }

    if (result.isDarwin() or result.isAndroid() or os.tag == .linux) {
        try uv_sources.appendSlice(&.{
            "src/unix/proctitle.c",
        });
    }

    if (os.tag == .dragonfly or os.tag == .freebsd) {
        try uv_sources.appendSlice(&.{
            "src/unix/freebsd.c",
        });
    }

    if (os.tag == .dragonfly or os.tag == .freebsd or os.tag == .netbsd or os.tag == .openbsd or os.tag == .linux) {
        try uv_sources.appendSlice(&.{
            "src/unix/posix-hrtime.c",
            "src/unix/bsd-proctitle.c",
        });
    }

    if (result.isBSD()) { // incl Drawin
        try uv_sources.appendSlice(&.{
            "src/unix/bsd-ifaddrs.c",
            "src/unix/kqueue.c",
        });
    }

    if (os.tag == .freebsd) {
        try uv_sources.appendSlice(&.{
            "src/unix/random-getrandom.c",
        });
    }

    if (result.isDarwin() or os.tag == .openbsd) {
        try uv_sources.appendSlice(&.{
            "src/unix/random-getentropy.c",
        });
    }

    if (result.isDarwin()) {
        lib.defineCMacro("_DARWIN_UNLIMITED_SELECT", "1");
        lib.defineCMacro("_DARWIN_USE_64_BIT_INODE", "1");
        try uv_sources.appendSlice(&.{
            "src/unix/darwin-proctitle.c",
            "src/unix/darwin.c",
            "src/unix/fsevents.c",
        });
    }

    if (os.tag == .hurd and result.isGnu()) {
        lib.linkSystemLibrary("dl");
        try uv_sources.appendSlice(&.{
            "src/unix/bsd-ifaddrs.c",
            "src/unix/no-fsevents.c",
            "src/unix/no-proctitle.c",
            "src/unix/posix-hrtime.c",
            "src/unix/posix-poll.c",
            "src/unix/hurd.c",
        });
    }

    if (os.tag == .linux) {
        lib.defineCMacro("_GNU_SOURCE", "1");
        lib.defineCMacro("_POSIX_C_SOURCE", "200112");
        lib.linkSystemLibrary("dl");
        lib.linkSystemLibrary("rt");
        try uv_sources.appendSlice(&.{
            "src/unix/linux.c",
            "src/unix/procfs-exepath.c",
            "src/unix/random-getrandom.c",
            "src/unix/random-sysctl-linux.c",
        });
    }

    if (os.tag == .netbsd) {
        try uv_sources.appendSlice(&.{
            "src/unix/netbsd.c",
        });
        lib.linkSystemLibrary("kvm");
    }

    if (os.tag == .openbsd) {
        try uv_sources.appendSlice(&.{
            "src/unix/openbsd.c",
        });
    }

    if (os.tag == .haiku) {
        lib.defineCMacro("_BSD_SOURCE", "1");
        lib.linkSystemLibrary("bsd");
        lib.linkSystemLibrary("network");
        try uv_sources.appendSlice(&.{
            "src/unix/haiku.c",
            "src/unix/bsd-ifaddrs.c",
            "src/unix/no-fsevents.c",
            "src/unix/no-proctitle.c",
            "src/unix/posix-hrtime.c",
            "src/unix/posix-poll.c",
        });
    }

    lib.addCSourceFiles(.{
        .files = uv_sources.items,
        .flags = uv_cflags.items,
    });

    b.installArtifact(lib);
}
