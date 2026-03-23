const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const Config = @import("../data/game_config.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

var lc_uid_counter: u32 = 50_000_000;

pub fn onGiveLight(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.splitScalar(u8, std.mem.trim(u8, args, " \t\r\n"), ' ');

    const id_str = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /givelight <id> <level> <rank>\nExample: /givelight 23002 80 5\n", allocator);
        return;
    };

    const level_str = it.next() orelse "80";
    const rank_str = it.next() orelse "5";

    const id = std.fmt.parseInt(u32, id_str, 10) catch {
        try commandhandler.sendMessage(session, "Invalid ID.\n", allocator);
        return;
    };

    const level = std.fmt.parseInt(u32, level_str, 10) catch {
        try commandhandler.sendMessage(session, "Invalid level.\n", allocator);
        return;
    };

    const rank = std.fmt.parseInt(u32, rank_str, 10) catch {
        try commandhandler.sendMessage(session, "Invalid rank.\n", allocator);
        return;
    };

    var sync = protocol.PlayerSyncScNotify.init(allocator);
    defer sync.deinit();

    lc_uid_counter += 1;

    const equipment = protocol.Equipment{
        .unique_id = lc_uid_counter,
        .tid = id,
        .is_protected = true,
        .level = level,
        .rank = rank,
        .promotion = 6,
        .dress_avatar_id = 0,
    };

    AvatarManager.storeEquipment(equipment); // ← store so dress/undress handlers can find it

    try sync.equipment_list.append(equipment);
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);

    var msg_buf: [128]u8 = undefined;
    const msg = try std.fmt.bufPrint(&msg_buf, "Gave lightcone {d} | Level: {d} | Rank: {d}\n", .{ id, level, rank });
    try commandhandler.sendMessage(session, msg, allocator);
}
