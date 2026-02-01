const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dbc",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ncurses for TUI
    exe.linkSystemLibrary("ncursesw"); // wide char support
    exe.linkSystemLibrary("panel");

    // Database drivers
    exe.linkSystemLibrary("pq"); // PostgreSQL
    exe.linkSystemLibrary("sqlite3"); // SQLite
    exe.linkSystemLibrary("odbc"); // MSSQL via ODBC
    exe.linkSystemLibrary("mariadb"); // MariaDB

    exe.linkLibC();

    b.installArtifact(exe);

    // Tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
