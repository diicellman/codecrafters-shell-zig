const std = @import("std");

const Command = union(enum) {
    Exit: ?u8,
    // Help,
    Echo: []const u8,
    Type: []const u8,
    Unknown: []const u8,

    fn parse(input: []const u8) Command {
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
        if (std.mem.startsWith(u8, trimmed, "exit")) {
            var parts = std.mem.split(u8, trimmed, " ");
            _ = parts.next(); // Skip "exit"

            if (parts.next()) |code_str| {
                return Command{ .Exit = std.fmt.parseInt(u8, code_str, 10) catch null };
            } else {
                return Command{ .Exit = null };
            }
            // } else if (std.mem.eql(u8, trimmed, "help")) {
            //     return Command.Help;
        } else if (std.mem.startsWith(u8, trimmed, "echo ")) {
            return Command{ .Echo = trimmed[5..] };
        } else if (std.mem.startsWith(u8, trimmed, "type ")) {
            return Command{ .Type = trimmed[5..] };
        } else {
            return Command{ .Unknown = trimmed };
        }
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    while (true) {
        try stdout.print("$ ", .{});

        const stdin = std.io.getStdIn().reader();
        var buffer: [1024]u8 = undefined;
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        // TODO: Handle user input
        // _ = user_input;
        if (user_input.len > 0) {
            const command = Command.parse(user_input);
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
                    } else {
                        try stdout.print("{s}: not found\n", .{trimmed_cmd});
                    }
                },
                .Unknown => |cmd| {
                    try stdout.print("{s}: command not found\n", .{cmd});
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
