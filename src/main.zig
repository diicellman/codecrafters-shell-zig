const std = @import("std");

const Command = union(enum) {
    Exit,
    // Help,
    // Echo: []const u8,
    Unknown: []const u8,

    fn parse(input: []const u8) Command {
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
        if (std.mem.eql(u8, trimmed, "exit")) {
            return Command.Exit;
            // } else if (std.mem.eql(u8, trimmed, "help")) {
            //     return Command.Help;
            // } else if (std.mem.startsWith(u8, trimmed, "echo ")) {
            //     return Command{ .Echo = trimmed[5..] };
        } else {
            return Command{ .Unknown = trimmed };
        }
    }
};

pub fn main() !void {
    // Uncomment this block to pass the first stage
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
                .Exit => {
                    std.process.exit(0);
                },
                .Unknown => |cmd| {
                    try stdout.print("{s}: command not found\n", .{cmd});
                },
            }
            // try stdout.print("{s}: command not found\n", .{user_input});
            // try stdout.print("$ exit 0", .{});
            // std.process.exit(0);
        }
    }
}
