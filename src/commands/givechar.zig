const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const Packet = @import("../Packet.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const Uid = @import("../utils/uid.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const SceneManager = @import("../manager/scene_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGiveChar(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.splitScalar(u8, std.mem.trim(u8, args, " \t\r\n"), ' ');

    const id_str = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /givechar <id> <level> <eidolons>  e.g. /givechar 1102 80 6\n", allocator);
        return;
    };
    const level_str = it.next() orelse "80";
    const rank_str = it.next() orelse "6";

    const id = std.fmt.parseInt(u32, id_str, 10) catch {
        try commandhandler.sendMessage(session, "Invalid ID. Usage: /givechar <id> <level> <eidolons>\n", allocator);
        return;
    };
    const level = std.fmt.parseInt(u32, level_str, 10) catch {
        try commandhandler.sendMessage(session, "Invalid level.\n", allocator);
        return;
    };
    const rank = std.fmt.parseInt(u32, rank_str, 10) catch {
        try commandhandler.sendMessage(session, "Invalid eidolons value.\n", allocator);
        return;
    };

    var sync = protocol.PlayerSyncScNotify.init(allocator);
    defer sync.deinit();

    Uid.resetGlobalUidGens();

    var char = protocol.AvatarSync.init(allocator);

    var avatar = try AvatarManager.createAllAvatar(allocator, id);
    avatar.level = level;
    try char.avatar_list.append(avatar);

    var path_data = try AvatarManager.createAllAvatarPathData(allocator, id);
    path_data.rank = rank;
    try char.avatar_path_data_info_list.append(path_data);

    sync.avatar_sync = char;
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);

    var msg_buf: [128]u8 = undefined;
    const msg = try std.fmt.bufPrint(&msg_buf, "Gave character {d} | Level: {d} | Eidolons: {d}\n", .{ id, level, rank });
    try commandhandler.sendMessage(session, msg, allocator);

    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    var scene_manager = SceneManager.SceneManager.init(allocator);
    const scene_info = try scene_manager.createScene(20503, 20503001, 2050301, 1029);
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .lineup = lineup,
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .scene = scene_info,
    });
}
