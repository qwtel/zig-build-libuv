const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "uv_a",
        .target = target,
        .optimize = optimize,
    });

    // Include dirs
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("src"));

    const result = target.result;
    const os = result.os;

    var uv_defines = std.ArrayList([]const []const u8).init(b.allocator);
    var uv_sources = std.ArrayList([]const u8).init(b.allocator);
    var uv_cflags = std.ArrayList([]const u8).init(b.allocator);
    var uv_test_sources = std.ArrayList([]const u8).init(b.allocator);
    var uv_test_libraries = std.ArrayList([]const u8).init(b.allocator);
    defer uv_defines.deinit();
    defer uv_sources.deinit();
    defer uv_cflags.deinit();
    defer uv_test_sources.deinit();
    defer uv_test_libraries.deinit();

    // TODO: add lint flags from cmakelist.txt?
    try uv_cflags.appendSlice(&.{
        "-Wall",
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
        try uv_defines.append(&.{ "WIN32_LEAN_AND_MEAN", "1" });
        try uv_defines.append(&.{ "_WIN32_WINNT", "0x0602" });
        try uv_defines.append(&.{ "_CRT_DECLARE_NONSTDC_NAMES", "0" });

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
        try uv_test_libraries.appendSlice(&.{"ws2_32"});
        try uv_test_sources.appendSlice(&.{ "src/win/snprintf.c", "test/runner-win.c" });
    } else {
        try uv_defines.append(&.{ "_FILE_OFFSET_BITS", "64" });
        try uv_defines.append(&.{ "_LARGEFILE_SOURCE", "1" });
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
        try uv_test_sources.appendSlice(&.{"test/runner-unix.c"});
    }

    if (result.isAndroid()) {
        try uv_defines.append(&.{ "_GNU_SOURCE", "1" });
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

    if (os.tag == .dragonfly or os.tag == .freebsd or os.tag == .netbsd or os.tag == .openbsd) {
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
        try uv_defines.append(&.{ "_DARWIN_UNLIMITED_SELECT", "1" });
        try uv_defines.append(&.{ "_DARWIN_USE_64_BIT_INODE", "1" });
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
        try uv_defines.append(&.{ "_GNU_SOURCE", "1" });
        try uv_defines.append(&.{ "_POSIX_C_SOURCE", "200112" });
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
        try uv_defines.append(&.{ "_BSD_SOURCE", "1" });
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

    if (result.isBSD() or os.tag == .linux) {
        try uv_test_libraries.append("util");
    }

    lib.addCSourceFiles(.{
        .files = uv_sources.items,
        .flags = uv_cflags.items,
    });
    lib.linkLibC();

    for (uv_defines.items) |define| {
        lib.defineCMacro(define[0], define[1]);
    }

    lib.installHeadersDirectory(b.path("include"), "", .{});

    b.installArtifact(lib);

    const LIBUV_BUILD_TESTS = b.option(bool, "build-tests", "") orelse false;

    if (LIBUV_BUILD_TESTS) {
        try uv_test_sources.appendSlice(&.{
            "test/blackhole-server.c",
            "test/echo-server.c",
            "test/run-tests.c",
            "test/runner.c",
            "test/test-active.c",
            "test/test-async-null-cb.c",
            "test/test-async.c",
            "test/test-barrier.c",
            "test/test-callback-stack.c",
            "test/test-close-fd.c",
            "test/test-close-order.c",
            "test/test-condvar.c",
            "test/test-connect-unspecified.c",
            "test/test-connection-fail.c",
            "test/test-cwd-and-chdir.c",
            "test/test-default-loop-close.c",
            "test/test-delayed-accept.c",
            "test/test-dlerror.c",
            "test/test-eintr-handling.c",
            "test/test-embed.c",
            "test/test-emfile.c",
            "test/test-env-vars.c",
            "test/test-error.c",
            "test/test-fail-always.c",
            "test/test-fork.c",
            "test/test-fs-copyfile.c",
            "test/test-fs-event.c",
            "test/test-fs-poll.c",
            "test/test-fs.c",
            "test/test-fs-readdir.c",
            "test/test-fs-fd-hash.c",
            "test/test-fs-open-flags.c",
            "test/test-get-currentexe.c",
            "test/test-get-loadavg.c",
            "test/test-get-memory.c",
            "test/test-get-passwd.c",
            "test/test-getaddrinfo.c",
            "test/test-gethostname.c",
            "test/test-getnameinfo.c",
            "test/test-getsockname.c",
            "test/test-getters-setters.c",
            "test/test-gettimeofday.c",
            "test/test-handle-fileno.c",
            "test/test-homedir.c",
            "test/test-hrtime.c",
            "test/test-idle.c",
            "test/test-idna.c",
            "test/test-ip4-addr.c",
            "test/test-ip6-addr.c",
            "test/test-ip-name.c",
            "test/test-ipc-heavy-traffic-deadlock-bug.c",
            "test/test-ipc-send-recv.c",
            "test/test-ipc.c",
            "test/test-loop-alive.c",
            "test/test-loop-close.c",
            "test/test-loop-configure.c",
            "test/test-loop-handles.c",
            "test/test-loop-stop.c",
            "test/test-loop-time.c",
            "test/test-metrics.c",
            "test/test-multiple-listen.c",
            "test/test-mutexes.c",
            "test/test-not-readable-nor-writable-on-read-error.c",
            "test/test-not-writable-after-shutdown.c",
            "test/test-osx-select.c",
            "test/test-pass-always.c",
            "test/test-ping-pong.c",
            "test/test-pipe-bind-error.c",
            "test/test-pipe-close-stdout-read-stdin.c",
            "test/test-pipe-connect-error.c",
            "test/test-pipe-connect-multiple.c",
            "test/test-pipe-connect-prepare.c",
            "test/test-pipe-getsockname.c",
            "test/test-pipe-pending-instances.c",
            "test/test-pipe-sendmsg.c",
            "test/test-pipe-server-close.c",
            "test/test-pipe-set-fchmod.c",
            "test/test-pipe-set-non-blocking.c",
            "test/test-platform-output.c",
            "test/test-poll-close-doesnt-corrupt-stack.c",
            "test/test-poll-close.c",
            "test/test-poll-closesocket.c",
            "test/test-poll-multiple-handles.c",
            "test/test-poll-oob.c",
            "test/test-poll.c",
            "test/test-process-priority.c",
            "test/test-process-title-threadsafe.c",
            "test/test-process-title.c",
            "test/test-queue-foreach-delete.c",
            "test/test-random.c",
            "test/test-readable-on-eof.c",
            "test/test-ref.c",
            "test/test-run-nowait.c",
            "test/test-run-once.c",
            "test/test-semaphore.c",
            "test/test-shutdown-close.c",
            "test/test-shutdown-eof.c",
            "test/test-shutdown-simultaneous.c",
            "test/test-shutdown-twice.c",
            "test/test-signal-multiple-loops.c",
            "test/test-signal-pending-on-close.c",
            "test/test-signal.c",
            "test/test-socket-buffer-size.c",
            "test/test-spawn.c",
            "test/test-stdio-over-pipes.c",
            "test/test-strscpy.c",
            "test/test-strtok.c",
            "test/test-tcp-alloc-cb-fail.c",
            "test/test-tcp-bind-error.c",
            "test/test-tcp-bind6-error.c",
            "test/test-tcp-close-accept.c",
            "test/test-tcp-close-after-read-timeout.c",
            "test/test-tcp-close-while-connecting.c",
            "test/test-tcp-close.c",
            "test/test-tcp-close-reset.c",
            "test/test-tcp-connect-error-after-write.c",
            "test/test-tcp-connect-error.c",
            "test/test-tcp-connect-timeout.c",
            "test/test-tcp-connect6-error.c",
            "test/test-tcp-create-socket-early.c",
            "test/test-tcp-flags.c",
            "test/test-tcp-oob.c",
            "test/test-tcp-open.c",
            "test/test-tcp-read-stop.c",
            "test/test-tcp-read-stop-start.c",
            "test/test-tcp-rst.c",
            "test/test-tcp-shutdown-after-write.c",
            "test/test-tcp-try-write.c",
            "test/test-tcp-write-in-a-row.c",
            "test/test-tcp-try-write-error.c",
            "test/test-tcp-unexpected-read.c",
            "test/test-tcp-write-after-connect.c",
            "test/test-tcp-write-fail.c",
            "test/test-tcp-write-queue-order.c",
            "test/test-tcp-write-to-half-open-connection.c",
            "test/test-tcp-writealot.c",
            "test/test-test-macros.c",
            "test/test-thread-affinity.c",
            "test/test-thread-equal.c",
            "test/test-thread.c",
            "test/test-thread-priority.c",
            "test/test-threadpool-cancel.c",
            "test/test-threadpool.c",
            "test/test-timer-again.c",
            "test/test-timer-from-check.c",
            "test/test-timer.c",
            "test/test-tmpdir.c",
            "test/test-tty-duplicate-key.c",
            "test/test-tty-escape-sequence-processing.c",
            "test/test-tty.c",
            "test/test-udp-alloc-cb-fail.c",
            "test/test-udp-bind.c",
            "test/test-udp-connect.c",
            "test/test-udp-connect6.c",
            "test/test-udp-create-socket-early.c",
            "test/test-udp-dgram-too-big.c",
            "test/test-udp-ipv6.c",
            "test/test-udp-mmsg.c",
            "test/test-udp-multicast-interface.c",
            "test/test-udp-multicast-interface6.c",
            "test/test-udp-multicast-join.c",
            "test/test-udp-multicast-join6.c",
            "test/test-udp-multicast-ttl.c",
            "test/test-udp-open.c",
            "test/test-udp-options.c",
            "test/test-udp-send-and-recv.c",
            "test/test-udp-send-hang-loop.c",
            "test/test-udp-send-immediate.c",
            "test/test-udp-sendmmsg-error.c",
            "test/test-udp-send-unreachable.c",
            "test/test-udp-try-send.c",
            "test/test-udp-recv-in-a-row.c",
            "test/test-uname.c",
            "test/test-walk-handles.c",
            "test/test-watcher-cross-stop.c",
        });

        const exe = b.addExecutable(.{
            .name = "uv_run_tests_a",
            .target = target,
            .optimize = optimize,
        });

        for (uv_defines.items) |define| {
            exe.defineCMacro(define[0], define[1]);
        }

        exe.addCSourceFiles(.{
            .files = uv_test_sources.items,
            .flags = uv_cflags.items,
        });

        exe.linkLibC();
        exe.linkLibrary(lib);

        for (uv_test_libraries.items) |uv_test_library| {
            exe.linkSystemLibrary(uv_test_library);
        }

        b.installArtifact(exe);
    }
}
