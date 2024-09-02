const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const ArrayList = std.ArrayList;

const Command = union(enum) {
    Exit: ?u8,
    Echo: []const u8,
    Type: []const u8,
    Unknown: []const u8,
    External: struct {
        program: []const u8,
        args: []const []const u8,
    },

    fn parse(input: []const u8, allocator: mem.Allocator) !Command {
        var parts = mem.split(u8, input, " ");
        const first = parts.next() orelse return Command{ .Unknown = input };

        if (mem.eql(u8, first, "exit")) {
            if (parts.next()) |code_str| {
                return Command{ .Exit = std.fmt.parseInt(u8, code_str, 10) catch null };
            } else {
                return Command{ .Exit = null };
            }
        } else if (mem.eql(u8, first, "echo")) {
            return Command{ .Echo = input[5..] };
        } else if (mem.eql(u8, first, "type")) {
            return Command{ .Type = input[5..] };
        } else {
            var args = ArrayList([]const u8).init(allocator);
            try args.append(first);
            while (parts.next()) |arg| {
                try args.append(arg);
            }
            return Command{ .External = .{ .program = first, .args = try args.toOwnedSlice() } };
        }
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    while (true) {
        try stdout.print("$ ", .{});

        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        // TODO: Handle user input
        // _ = user_input;
        if (user_input.len > 0) {
            const command = try Command.parse(user_input, allocator);
            switch (command) {
                .Exit => |maybe_code| {
                    const status_code = maybe_code orelse 0;
                    std.process.exit(status_code);
                },
                .Echo => |text| {
                    try stdout.print("{s}\n", .{text});
                },
                .Type => |cmd| {
                    const trimmed_cmd = std.mem.trim(u8, cmd, &std.ascii.whitespace);
                    if (isBuiltinCommand(trimmed_cmd)) {
                        try stdout.print("{s} is a shell builtin\n", .{trimmed_cmd});
                    } else if (try findExecutable(allocator, trimmed_cmd)) |path| {
                        try stdout.print("{s} is {s}\n", .{ trimmed_cmd, path });
                    } else {
                        try stdout.print("{s}: not found\n", .{trimmed_cmd});
                    }
                },
                .Unknown => |cmd| {
                    try stdout.print("{s}: command not found\n", .{cmd});
                },
                .External => |ext| {
                    if (try findExecutable(allocator, ext.args[0]) != null) {
                        var child = std.process.Child.init(ext.args, allocator);
                        // defer child.deinit();
                        // child.stdin_behavior = .Inherit;
                        // child.stdout_behavior = .Inherit;
                        // child.stderr_behavior = .Inherit;
                        // child.env_map = try std.process.getEnvMap(allocator);

                        const term = try child.spawnAndWait();
                        switch (term) {
                            .Exited => |code| {
                                if (code != 0) {
                                    try stdout.print("Program exited with non-zero status code: {d}\n", .{code});
                                }
                            },
                            else => try stdout.print("Program terminated abnormally\n", .{}),
                        }
                    } else {
                        try stdout.print("{s}: command not found\n", .{ext.args[0]});
                    }
                },
            }
        }
    }
}

fn isBuiltinCommand(cmd: []const u8) bool {
    const builtins = [_][]const u8{ "exit", "help", "echo", "type" };
    for (builtins) |builtin| {
        if (std.mem.eql(u8, cmd, builtin)) {
            return true;
        }
    }
    return false;
}

fn findExecutable(allocator: mem.Allocator, arg: []const u8) !?[]const u8 {
    const env_vars = try std.process.getEnvMap(allocator);
    // defer env_vars.deinit();

    const path_value = env_vars.get("PATH") orelse "";
    var path_it = mem.split(u8, path_value, ":");

    while (path_it.next()) |path| {
        const full_path = try fs.path.join(allocator, &[_][]const u8{ path, arg });
        defer allocator.free(full_path);

        const file = fs.openFileAbsolute(full_path, .{ .mode = .read_only }) catch {
            continue;
        };
        defer file.close();

        const mode = file.mode() catch {
            continue;
        };

        const is_executable = mode & 0b001 != 0;
        if (!is_executable) {
            continue;
        }

        return try allocator.dupe(u8, full_path);
    }

    return null;
}

// fn runExternalProgram(allocator: mem.Allocator, program: []const u8, args: []const []const u8) !void {
//     var full_args = try ArrayList([]const u8).initCapacity(allocator, args.len + 1);
//     defer full_args.deinit();
//
//     try full_args.append(program);
//     try full_args.appendSlice(args);
//
//     var child = std.process.Child.init(full_args.items, allocator);
//     child.stdin_behavior = .Inherit;
//     child.stdout_behavior = .Pipe;
//     child.stderr_behavior = .Pipe;
//
//     try child.spawn();
//
//     const stdout = try child.stdout.?.reader().readAllAlloc(allocator, 1024 * 1024);
//     defer allocator.free(stdout);
//
//     const stderr = try child.stderr.?.reader().readAllAlloc(allocator, 1024 * 1024);
//     defer allocator.free(stderr);
//
//     const term = try child.wait();
//
//     const stdoutWriter = std.io.getStdOut().writer();
//     try stdoutWriter.writeAll(stdout);
//     try stdoutWriter.writeAll(stderr);
//
//     switch (term) {
//         .Exited => |code| {
//             if (code != 0) {
//                 try stdoutWriter.print("Program exited with non-zero status code: {d}\n", .{code});
//             }
//         },
//         else => try stdoutWriter.print("Program terminated abnormally\n", .{}),
//     }
// }
