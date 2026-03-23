const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const commandhandler = @import("../command.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const B64Decoder = std.base64.standard.Decoder;

const EmojiList = [_]u32{};

pub fn onGetFriendListInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetFriendListInfoScRsp.init(allocator);
    rsp.retcode = 0;

    var assist_list = ArrayList(protocol.AssistSimpleInfo).init(allocator);
    try assist_list.appendSlice(&[_]protocol.AssistSimpleInfo{
        .{ .pos = 0, .level = 80, .avatar_id = 1006, .dressed_skin_id = 0 },
        .{ .pos = 1, .level = 80, .avatar_id = 1006, .dressed_skin_id = 0 },
        .{ .pos = 2, .level = 80, .avatar_id = 1006, .dressed_skin_id = 0 },
    });

    var friend = protocol.FriendSimpleInfo.init(allocator);
    friend.playing_state = .PLAYING_CHALLENGE_PEAK;
    friend.create_time = 0;
    friend.remark_name = .{ .Const = "Silver Wolf" };
    friend.is_marked = true;
    friend.player_info = protocol.PlayerSimpleInfo{
        .personal_card = 253001,
        .signature = .{ .Const = "lol ur getting hacked rn" },
        .nickname = .{ .Const = "Silver Wolf Lv.999" },
        .level = 70,
        .uid = 2000,
        .head_icon = 201006, // Silver Wolf icon
        .head_frame_info = .{
            .head_frame_expire_time = 4294967295,
            .head_frame_item_id = 226004,
        },
        .chat_bubble_id = 220008,
        .assist_simple_info_list = assist_list,
        .platform = protocol.PlatformType.ANDROID,
        .online_status = protocol.FriendOnlineStatus.FRIEND_ONLINE_STATUS_ONLINE,
    };
    try rsp.friend_list.append(friend);
    try session.send(CmdID.CmdGetFriendListInfoScRsp, rsp);
}

pub fn onChatEmojiList(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetChatEmojiListScRsp.init(allocator);

    rsp.retcode = 0;
    try rsp.chat_emoji_list.appendSlice(&EmojiList);

    try session.send(CmdID.CmdGetChatEmojiListScRsp, rsp);
}
pub fn onPrivateChatHistory(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetPrivateChatHistoryScRsp.init(allocator);
    rsp.retcode = 0;
    rsp.target_side = 1;
    rsp.contact_side = 2000;

    const sender_uid: u32 = 2000;

    // Newest first, oldest last
    const welcome_messages = [_][]const u8{
        "oh and /help exists for commands, remember, you cant say anything here without using / first.",
        "i've already poked around your systems a bit. interesting setup you've got.",
        "not here for anything serious. was just playing honkai impact, thought i'd drop by.",
        "oh, it's you. hey Trailblazer, yeah, you behind the screen.",
    };

    for (welcome_messages) |line| {
        if (line.len == 0) continue;
        const msg = try makeTextChat(allocator, sender_uid, line);
        try rsp.chat_message_list.append(msg);
    }

    try session.send(CmdID.CmdGetPrivateChatHistoryScRsp, rsp);
}
pub fn onGetAiPamChatHistory(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var rsp = protocol.GetAiPamChatHistoryScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.target_side = 1;
    try rsp.BAPMDIEFDOJ.appendSlice(&[_]protocol.ChatMessageData{
        try makeTextChat(allocator, 2000, "Kill all nantong :Đ"),
    });

    try session.send(CmdID.CmdGetAiPamChatHistoryScRsp, rsp);
}

fn makeTextChat(
    allocator: Allocator,
    uid: u32,
    text: []const u8,
) !protocol.ChatMessageData {
    var datas = std.ArrayList(protocol.MessageChatData).init(allocator);
    try datas.append(.{
        .message_type = .MSG_TYPE_CUSTOM_TEXT,
        .chat_data = .{
            .extend_type = .{
                .message_text = .{ .Const = text },
            },
        },
    });

    return .{
        .message_datas = datas,
        .AEELKNKIICI = .{
            .FPCDPDPHKJJ = .{ .uid = uid },
        },
    };
}

pub fn onSendMsg(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    std.debug.print("Received packet: {any}\n", .{packet});
    const req = protocol.SendMsgCsReq.init(allocator);
    defer req.deinit();

    std.debug.print("Decoded request: {any}\n", .{req});
    std.debug.print("Raw packet body: {any}\n", .{packet.body});
    var msg_text: []const u8 = "";
    if (packet.body.len > 9 and packet.body[9] == 47) {
        msg_text = packet.body[9 .. packet.body.len - 6];
    }
    std.debug.print("Manually extracted message text: '{s}'\n", .{msg_text});

    if (msg_text.len > 0) {
        if (std.mem.indexOf(u8, msg_text, "/") != null) {
            std.debug.print("Message contains a '/'\n", .{});
            try commandhandler.handleCommand(session, msg_text, allocator);
        } else {
            std.debug.print("Message does not contain a '/'\n", .{});
            try commandhandler.sendMessage(session, msg_text, allocator);
        }
    } else {
        std.debug.print("Empty message received\n", .{});
    }

    var rsp = protocol.SendMsgScRsp.init(allocator);
    rsp.retcode = 0;
    try session.send(CmdID.CmdSendMsgScRsp, rsp);
}

pub fn onTriggerAiPamSpeak(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.TriggerAiPamSpeakCsReq, allocator);
    defer req.deinit();
    try session.send(CmdID.CmdTriggerAiPamSpeakScRsp, protocol.TriggerAiPamSpeakScRsp{
        .CEHJJGEIMCL = req.CEHJJGEIMCL,
        .retcode = 0,
    });
}
