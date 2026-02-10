const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dbc",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // ncurses for TUI
    exe.linkSystemLibrary("ncursesw"); // wide char support
    exe.linkSystemLibrary("panel");

    // Database drivers
    exe.linkSystemLibrary("pq"); // PostgreSQL
    // TODO: Uncomment these when implementing other drivers
    // exe.linkSystemLibrary("sqlite3"); // SQLite
    // exe.linkSystemLibrary("odbc"); // MSSQL via ODBC
    // exe.linkSystemLibrary("mariadb"); // MariaDB

    exe.linkLibC();

    // Add library search paths for macOS Homebrew
    if (target.result.os.tag == .macos) {
        // Common Homebrew paths for Apple Silicon and Intel Macs
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" }); // Apple Silicon
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/postgresql/lib" }); // Apple Silicon PostgreSQL
        exe.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" }); // Intel Mac
        exe.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/postgresql/lib" }); // Intel Mac PostgreSQL

        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" }); // Apple Silicon
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/postgresql/include" }); // Apple Silicon PostgreSQL
        exe.addIncludePath(.{ .cwd_relative = "/usr/local/include" }); // Intel Mac
        exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/postgresql/include" }); // Intel Mac PostgreSQL
    }

    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
        }),
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
