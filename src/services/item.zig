const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const Sync = @import("../commands/sync.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;

pub fn onGetBag(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetBagScRsp.init(allocator);
    rsp.equipment_list = ArrayList(protocol.Equipment).init(allocator);
    rsp.relic_list = ArrayList(protocol.Relic).init(allocator);
    for (Data.ItemList) |tid| {
        try rsp.material_list.append(.{ .tid = tid, .num = 100 });
    }
    for (Data.PlayerOutfitList) |tid| {
        try rsp.material_list.append(.{ .tid = tid, .num = 1 });
    }
    for (config.avatar_config.items) |avatarConf| {
        const lc = try AvatarManager.createEquipment(avatarConf.lightcone, avatarConf.id);
        try rsp.equipment_list.append(lc);
        for (avatarConf.relics.items) |input| {
            const r = try AvatarManager.createRelic(allocator, input, avatarConf.id);
            try rsp.relic_list.append(r);
        }
    }
    try session.send(CmdID.CmdGetBagScRsp, rsp);
}

pub fn onDressEquipment(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.DressEquipmentCsReq, allocator);
    defer req.deinit();

    // Update the lightcone's dress_avatar_id in the bag response
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    defer sync.deinit();

    var equipment_list = ArrayList(protocol.Equipment).init(allocator);
    try equipment_list.append(protocol.Equipment{
        .unique_id = req.equipment_unique_id,
        .dress_avatar_id = req.avatar_id,
        .tid = 0, // client already knows the tid
        .is_protected = true,
        .level = 1,
        .rank = 1,
        .promotion = 0,
    });

    sync.equipment_list = equipment_list;
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
    try session.send(CmdID.CmdDressEquipmentScRsp, protocol.DressEquipmentScRsp{
        .retcode = 0,
        .avatar_id = req.avatar_id,
        .equipment_unique_id = req.equipment_unique_id,
    });
}

pub fn onTakeOffEquipment(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TakeOffEquipmentCsReq, allocator);
    defer req.deinit();

    var sync = protocol.PlayerSyncScNotify.init(allocator);
    defer sync.deinit();

    var equipment_list = ArrayList(protocol.Equipment).init(allocator);
    try equipment_list.append(protocol.Equipment{
        .unique_id = req.equipment_unique_id,
        .dress_avatar_id = 0, // unequipped
        .tid = 0,
        .is_protected = true,
        .level = 1,
        .rank = 1,
        .promotion = 0,
    });

    sync.equipment_list = equipment_list;
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
    try session.send(CmdID.CmdTakeOffEquipmentScRsp, protocol.TakeOffEquipmentScRsp{
        .retcode = 0,
        .avatar_id = req.avatar_id,
        .equipment_unique_id = req.equipment_unique_id,
    });
}

pub fn onUseItem(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.UseItemCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.UseItemScRsp.init(allocator);
    rsp.use_item_id = req.use_item_id;
    rsp.use_item_count = req.use_item_count;
    rsp.retcode = 0;
    var sync = protocol.SyncLineupNotify.init(allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    sync.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync);
    try session.send(CmdID.CmdUseItemScRsp, rsp);
}
