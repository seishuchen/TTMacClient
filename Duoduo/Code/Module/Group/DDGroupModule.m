/************************************************************
 * @file         DDGroupModule.h
 * @author       快刀<kuaidao@mogujie.com>
 * summery       群主列表管理
 ************************************************************/

#import "DDGroupModule.h"
#import "GroupHandler.h"
#import "GroupEntity.h"
#import "SessionEntity.h"
#import "MessageEntity.h"
#import "DDSessionModule.h"
#import "DDMessageModule.h"
#import "DDLogic.h"
#import "TcpProtocolPack.h"
#import "SpellLibrary.h"
#import "DDMainModule.h"
#import "DDUserlistModule.h"
#import "DDSetting.h"
#import "DDTcpClientManager.h"

#import "DDReceiveGroupAddMemberAPI.h"
#import "DDReceiveGroupDeleteMemberAPI.h"
#import "DDGroupInfoAPI.h"

DDGroupModule* getDDGroupModule()
{
    return (DDGroupModule*)[[DDLogic instance] queryModuleByID:MODULE_ID_GROUP];
}

@interface DDGroupModule()

-(void)onHandleTcpData:(uint16)cmdId data:(id)data;
-(void)addGroup:(GroupEntity*)newGroup;
-(void)registerAPI;


@end

@implementation DDGroupModule
{
    NSArray* _ignoreGroups;
}
-(id) initModule
{
    if(self = [super initModule:MODULE_ID_GROUP])
    {
        _allGroups = [[NSMutableDictionary alloc] init];
        _allFixedGroup = [[NSMutableDictionary alloc] init];
        _ignoreGroups = @[];
        [self registerAPI];
    }
    return self;
}

-(BOOL)isInIgnoreGroups:(NSString*)groupID
{
    return [_ignoreGroups containsObject:groupID];
}

-(void)addGroup:(GroupEntity*)newGroup
{
    if (!newGroup)
    {
        return;
    }
    GroupEntity* group = newGroup;
    if([self isContainGroup:newGroup.groupId])
    {
        group = [_allGroups valueForKey:newGroup.groupId];
        [group copyContent:newGroup];
    }
    [_allGroups setObject:group forKey:group.groupId];
    DDSessionModule* sessionModule = getDDSessionModule();
    NSArray* recentleSession = [sessionModule recentlySessionIds];
    if ([recentleSession containsObject:group.groupId] &&
        ![sessionModule getSessionBySId:group.groupId])
    {
        //针对最近联系人列表中出现的空白行的情况
        SessionEntity* session = [[SessionEntity alloc] init];
        session.sessionId = group.groupId;
        session.type = group.groupType + 1;
        session.lastSessionTime = group.groupUpdated;
        [sessionModule addSession:session];

        [[NSNotificationCenter defaultCenter] postNotificationName:RELOAD_RECENT_ESSION_ROW object:group.groupId];
    }
    newGroup = nil;
}

- (void)addFixedGroup:(GroupEntity*)newGroup
{
    GroupEntity* group = newGroup;
    if([self isFixGroupsContainGroup:newGroup.groupId])
    {
        group = [_allFixedGroup valueForKey:newGroup.groupId];
        [group copyContent:newGroup];
    }
    [_allFixedGroup setObject:group forKey:group.groupId];
    newGroup = nil;
}

-(void)onHandleTcpData:(uint16)cmdId data:(id)data
{
    if(CMD_ID_GROUP_USER_LIST_RES == cmdId)
    {
        GroupEntity* dataGroup = (GroupEntity*)data;
        if(!dataGroup)
            return;

        if (![_recentlyGroupIds containsObject:dataGroup.groupId])
        {
            [_recentlyGroupIds addObject:dataGroup.groupId];
            DDSessionModule* sessionModule = getDDSessionModule();
            SessionEntity* session = [sessionModule createGroupSession:dataGroup.groupId type:dataGroup.groupType];
            [sessionModule addSession:session];
//            [getDDSessionModule() sortRecentlySessions];
        }
        
        if(![self isContainGroup:dataGroup.groupId])
        {
            [self addGroup:dataGroup];
        }
        
        GroupEntity* group = [self getGroupByGId:dataGroup.groupId];
        group.groupType = dataGroup.groupType;
        group.name = dataGroup.name;
        group.avatar = dataGroup.avatar;
        group.groupUserIds = dataGroup.groupUserIds;
    }
    else if(CMD_ID_GROUP_UNREAD_CNT_RES == cmdId)
    {
        NSArray* unReadMsgGroupIds = (NSArray*)data;
        for(NSString* gId in unReadMsgGroupIds)
        {
            [[DDLogic instance] pushTaskWithBlock:
                     ^()
                     {
                         NSMutableData *dataUnreadMsgReq = [TcpProtocolPack getGroupUnreadMsgRequest:gId];
                         [[DDTcpClientManager instance] writeToSocket:dataUnreadMsgReq];
                     }];
        }
    }
    else if(CMD_ID_GROUP_UNREAD_MSG_RES == cmdId)
    {
        NSDictionary *unreadMsgDict = (NSDictionary *)data;
        NSArray* unReadMsgArray = [unreadMsgDict objectForKey:@"msg"];
        if(!unReadMsgArray || unReadMsgArray.count < 1)
            return;
        
        DDMessageModule* moduleMessage = getDDMessageModule();
        NSString* sId,*orginId;
        for(NSUInteger i = [unReadMsgArray count]; i > 0; --i)
        {
            MessageEntity* msg = [unReadMsgArray objectAtIndex:i-1];
            sId = msg.sessionId;
            orginId = msg.orginId;
            //先清空下未读消息，服务器端会再次送过来
            if(i == [unReadMsgArray count])
            {
                [moduleMessage removeArrayMessage:sId];
            }
            //判断是否是屏蔽消息
            NSArray* shieldSessions = [[DDSetting instance] getShieldSessionIDs];
            if (![shieldSessions containsObject:sId])
            {
                [moduleMessage pushMessage:sId message:msg];
            }
        }
        //如果离线消息的群信息不存在，则需要获取
        if(![self isContainGroup:sId])
        {
            [self tcpGetUnkownGroupInfo:orginId];
            return;
        }
        
        //如果会话不存在，则创建
        DDSessionModule* moduleSess = getDDSessionModule();
        if(![moduleSess isContianSession:sId])
        {
            [moduleSess createSingleSession:sId];
        }
        SessionEntity* session = [moduleSess getSessionBySId:sId];
        session.lastSessionTime = time(0);
        //排序
//        [moduleSess sortRecentlySessions];
        [self uiAsyncNotify:MKN_DDSESSIONMODULE_RECENTLYLIST userInfo:nil];
        
        NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:sId forKey:USERINFO_SID];
        [self uiAsyncNotify:MKN_DDSESSIONMODULE_GROUPMSG userInfo:userInfo];
    }
    else if(CMD_ID_GROUP_HISTORY_MSG_RES == cmdId)
    {
        NSDictionary *historyMsgDict = (NSDictionary *)data;
        NSArray* historyMsgArray = [historyMsgDict objectForKey:@"msg"];
        //if(!historyMsgArray || historyMsgArray.count < 1)
        //    return;
        
        NSString* sId = [historyMsgDict objectForKey:@"sessionId"];
        DDMessageModule* moduleMessage = getDDMessageModule();
        for(NSUInteger i = [historyMsgArray count]; i > 0; --i)
        {
            MessageEntity* msg = [historyMsgArray objectAtIndex:i-1];
            //sId = msg.sessionId;
            [moduleMessage pushMessage:sId message:msg];
        }
        NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:sId forKey:USERINFO_SID];
        [self uiAsyncNotify:MKN_DDSESSIONMODULE_HISTORYMSG userInfo:userInfo];
    }else if(CMD_ID_GROUP_CREATE_TMP_GROUP_RES ==cmdId ){   //创建临时群的返回
        GroupEntity* group = (GroupEntity *)data;
        group.groupCreatorId = [getDDUserlistModule() myUserId];
        if (!group) {
            return;
        }
        

        NSMutableArray *unknowUserIds = [[NSMutableArray alloc] init];
        DDUserlistModule *userListModule =  getDDUserlistModule();
        
        for (NSString *userId in group.groupUserIds) {
            if (![userListModule isContianUser:userId]) {
                [unknowUserIds addObject:userId];
            }
        }
        if ([unknowUserIds count]>0) {
            NSMutableData *dateGetUserInfoMsg = [TcpProtocolPack getUserInfoListReq:unknowUserIds];
            [[DDTcpClientManager instance] writeToSocket:dateGetUserInfoMsg];
        }
       
        
        [_recentlyGroupIds addObject:group.groupId];
        [_allGroups setObject:group forKey:group.groupId];
        [[DDMainWindowController instance] openChatViewByUserId:group.groupId];
    }else if(CMD_ID_GROUP_JOIN_GROUP_RES == cmdId){     //加入临时群时的返回.
        GroupEntity* group = (GroupEntity *)data;
        if (!group) {
            return;
        }
        
        
        NSMutableArray *unknowUserIds = [[NSMutableArray alloc] init];
        DDUserlistModule *userListModule =  getDDUserlistModule();
        
        for (NSString *userId in group.groupUserIds) {
            if (![userListModule isContianUser:userId]) {
                [unknowUserIds addObject:userId];
            }
        }
        if ([unknowUserIds count]>0) {
            NSMutableData *dateGetUserInfoMsg = [TcpProtocolPack getUserInfoListReq:unknowUserIds];
            [[DDTcpClientManager instance] writeToSocket:dateGetUserInfoMsg];
        }
        
        DDSessionModule* sessionModule = getDDSessionModule();
        if ([sessionModule.recentlySessionIds containsObject:group.groupId])
        {
            //自己本身就在群中，这时需要刷新界面
            NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:group.groupId,USERINFO_SID, nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:MKN_DDSESSIONMODULE_GROUPMEMBER object:nil userInfo:userInfo];
        }
        else
        {
            //TODO:本身不在群中，这里是否要更新最近联系人列表
        }
        
    }else if (CMD_ID_GROUP_QUIT_GROUP_RES == cmdId)
    {
        GroupEntity* group = (GroupEntity *)data;
        if (!group)
        {
            return;
        }
        NSString* myID = [getDDUserlistModule() myUserId];
        if ([group.groupUserIds containsObject:myID])
        {
            //通知更新群组成员列表
            NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:group.groupId,USERINFO_SID, nil];
            [[NSNotificationCenter defaultCenter]postNotificationName:MKN_DDSESSIONMODULE_GROUPMEMBER object:nil userInfo:userInfo];
        }
        else
        {
            //自己被提出去群了
            [self.recentlyGroupIds removeObject:group.groupId];
            DDSessionModule* sessionModule = getDDSessionModule();
            [sessionModule.recentlySessionIds removeObject:group.groupId];
            [[NSNotificationCenter defaultCenter] postNotificationName:MKN_DDSESSIONMODULE_DELETEDFROMGROUP object:group.groupId];
        }
    }
}

-(void)tcpGetUnkownGroupInfo:(NSString*)gId
{
    [[DDLogic instance] pushTaskWithBlock:
             ^
             {
                 NSMutableData* data = [TcpProtocolPack getGroupInfoRequest:gId];
                 [[DDTcpClientManager instance] writeToSocket:data];
             }];
}

-(GroupEntity*)getGroupByGId:(NSString*)gId
{
    return [_allGroups valueForKey:gId];
}

-(BOOL)isContainGroup:(NSString*)gId
{
    return ([_allGroups valueForKey:gId] != nil);
}

- (BOOL)isFixGroupsContainGroup:(NSString*)gId
{
    return ([_allFixedGroup valueForKey:gId] != nil);
}

-(NSArray*)getAllGroups
{
    return [_allGroups allValues];
}

-(NSArray*)getAllFixedGroups
{
    return [_allFixedGroup allValues];
}

- (void)getGroupInfogroupID:(NSString*)groupID completion:(GetGroupInfoCompletion)completion
{
    NSString* lookGroupID = [groupID hasPrefix:GROUP_PRE] ? groupID : [NSString stringWithFormat:@"%@%@",GROUP_PRE,groupID];
    GroupEntity* localGroup = [self getGroupByGId:lookGroupID];
    if (localGroup)
    {
        completion(localGroup);
        return;
    }
    DDGroupInfoAPI* groupInfo = [[DDGroupInfoAPI alloc] init];
    
    NSString* serverGroupID = [lookGroupID substringFromIndex:[GROUP_PRE length]];
    
    [groupInfo requestWithObject:serverGroupID Completion:^(id response, NSError *error) {
        if (!error)
        {
            GroupEntity* group = (GroupEntity*)response;
            if (group)
            {
                [self addGroup:group];
            }
            completion(group);
        }
        else
        {
            DDLog(@"error:%@ groupID:%@",[error domain],groupID);
            [self getGroupInfogroupID:groupID completion:completion];
        }
    }];
}

- (void)registerAPI
{
    DDReceiveGroupAddMemberAPI* addmemberAPI = [[DDReceiveGroupAddMemberAPI alloc] init];
    [addmemberAPI registerAPIInAPIScheduleReceiveData:^(id object, NSError *error) {
        if (!error)
        {
            
            GroupEntity* groupEntity = (GroupEntity*)object;
            if (!groupEntity)
            {
                return;
            }
            if ([self getGroupByGId:groupEntity.groupId])
            {
                //自己本身就在组中
                [[DDMainWindowController instance] updateCurrentChattingViewController];
            }
            else
            {
                //自己被添加进组中
                
                groupEntity.groupUpdated = [[NSDate date] timeIntervalSince1970];
                [self addGroup:groupEntity];
                DDSessionModule* sessionModule = getDDSessionModule();
                [sessionModule createGroupSession:groupEntity.groupId type:GROUP_TYPE_TEMPORARY];
                [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:nil];
            }
        }
        else
        {
            DDLog(@"error:%@",[error domain]);
        }
    }];
    
    DDReceiveGroupDeleteMemberAPI* deleteMemberAPI = [[DDReceiveGroupDeleteMemberAPI alloc] init];
    [deleteMemberAPI registerAPIInAPIScheduleReceiveData:^(id object, NSError *error) {
        if (!error)
        {
            GroupEntity* groupEntity = (GroupEntity*)object;
            if (!groupEntity)
            {
                return;
            }
            DDUserlistModule* userModule = getDDUserlistModule();
            if ([groupEntity.groupUserIds containsObject:userModule.myUserId])
            {
                //别人被踢了
                [[DDMainWindowController instance] updateCurrentChattingViewController];
            }
            else
            {
                //自己被踢了
                [self.recentlyGroupIds removeObject:groupEntity.groupId];
                DDSessionModule* sessionModule = getDDSessionModule();
                [sessionModule.recentlySessionIds removeObject:groupEntity.groupId];
                DDMessageModule* messageModule = getDDMessageModule();
                [messageModule popArrayMessage:groupEntity.groupId];
                [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:nil];
            }
        }
    }];
}

@end
