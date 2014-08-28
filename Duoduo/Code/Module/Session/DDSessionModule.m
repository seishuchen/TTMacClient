/************************************************************
 * @file         DDSessionModule.m
 * @author       快刀<kuaidao@mogujie.com>
 * summery       会话模块
 ************************************************************/

#import "DDSessionModule.h"
#import "DDMessageModule.h"
#import "DDUserlistModule.h"
#import "DDGroupModule.h"
#import "DDModuleID.h"
#import "MessageEntity.h"
#import "SessionEntity.h"
#import "GroupEntity.h"
#import "ImMessageHandler.h"
#import "TcpProtocolPack.h"
#import "UserEntity.h"
#import "DDSetting.h"
#import "DDDatabaseUtil.h"
#import "DDTcpClientManager.h"
#import "DDGroupInfoAPI.h"
#import "DDUserInfoAPI.h"
#import "DDUserMsgReadACKAPI.h"
#import "DDGroupMsgReadACKAPI.h"

DDSessionModule* getDDSessionModule()
{
    return (DDSessionModule*)[[DDLogic instance] queryModuleByID:MODULE_ID_SESSION];
}

@interface DDSessionModule()

-(void)onHandleTcpData:(uint16)cmdId data:(id)data;

- (void)n_receiveReceiveMessageNotification:(NSNotification*)notification;

@end

@implementation DDSessionModule
{
    NSString* _chattingSessionID;
}
-(id) initModule
{
    if(self = [super initModule:MODULE_ID_SESSION])
    {        
        _allSessions = [[NSMutableDictionary alloc] init];
        _recentlySessionIds = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveReceiveMessageNotification:) name:notificationReceiveMessage object:nil];
        [self addObserver:self forKeyPath:@"_recentlySessionIds" options:0 context:nil];
    }
    return self;   
}

-(void) onLoadModule
{
}



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationReceiveMessage object:nil];
    [self removeObserver:self forKeyPath:@"_recentlySessionIds"];
}

#pragma mark TcpHandle
-(void)onHandleTcpData:(uint16)cmdId data:(id)data
{
    if(CMD_MSG_DATA == cmdId)
    {
        MessageEntity* msg = (MessageEntity*)data;
        if(nil == msg)
            return;
        
        //判断是否在屏蔽的会话列表中
        NSArray* shieldSessions = [[DDSetting instance] getShieldSessionIDs];
        if ([shieldSessions containsObject:msg.sessionId])
        {
            SessionEntity* session = [self getSessionBySId:msg.sessionId];
            //插入历史消息数据库
            [[DDDatabaseUtil instance] insertMessage:msg success:^{
                
            } failure:^(NSString *errorDescripe) {
                DDLog(@"%@",errorDescripe);
            }];
            [self tcpSendReadedAck:session];
            return;
        }
        DDMessageModule* moduleMessage = getDDMessageModule();
        [moduleMessage pushMessage:msg.sessionId message:msg];
        [moduleMessage countHistoryMsgOffset:msg.sessionId offset:1];
        
        do
        {
            //如果消息的用户信息不存在，则需要获取
            if(MESSAGE_TYPE_GROUP == msg.msgType || MESSAGE_TYPE_TEMP_GROUP ==msg.msgType)
            {
                DDGroupModule* moduleGroup = getDDGroupModule();
                if(![moduleGroup isContainGroup:msg.sessionId])
                {
                    [moduleGroup tcpGetUnkownGroupInfo:msg.orginId];
                    break;
                }
            }
            else
            {
                DDUserlistModule* moduleUserlist = getDDUserlistModule();
                if(![moduleUserlist isContianUser:msg.sessionId])
                {
                    [moduleUserlist tcpGetUnkownUserInfo:msg.orginId];
                    break;
                }
            }
            
            //如果会话不存在，则创建
            if(![self.recentlySessionIds containsObject:msg.sessionId])
            {
                [self createSingleSession:msg.sessionId];
            }
            SessionEntity* session = [self getSessionBySId:msg.sessionId];
            session.lastSessionTime = time(0);
            //排序
            [self sortRecentlySessions];
            [self uiAsyncNotify:MKN_DDSESSIONMODULE_RECENTLYLIST userInfo:nil];
            
            NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:msg.sessionId forKey:USERINFO_SID];
            [userInfo setObject:msg forKey:USERINFO_DEFAULT_KEY];
            if(MESSAGE_TYPE_GROUP == msg.msgType || MESSAGE_TYPE_TEMP_GROUP==msg.msgType)
            {
                [self uiAsyncNotify:MKN_DDSESSIONMODULE_GROUPMSG userInfo:userInfo];
            }
            else
            {
                [self uiAsyncNotify:MKN_DDSESSIONMODULE_SINGLEMSG userInfo:userInfo];
            }
            
        }while(NO);
        
        //向服务器发送ack
        if(MESSAGE_TYPE_SINGLE == msg.msgType)
        {
            [[DDLogic instance] pushTaskWithBlock:
             ^()
             {
                 NSMutableData *msgDataAck = [TcpProtocolPack getMsgDataAck:msg.seqNo fromUser:msg.orginId];
                 [[DDTcpClientManager instance] writeToSocket:msgDataAck];
             }];
        }
    }
    else if(CMD_MSG_UNREAD_CNT_RES == cmdId)
    {
        NSArray* unReadMsgUserIds = (NSArray*)data;
        for(NSString* uId in unReadMsgUserIds)
        {
            [[DDLogic instance] pushTaskWithBlock:
                    ^()
                    {
                        NSMutableData *dataUnreadMsgReq = [TcpProtocolPack getUnreadMsgReq:uId];
                        [[DDTcpClientManager instance] writeToSocket:dataUnreadMsgReq];
                    }];
        }
    }
    else if(CMD_MSG_GET_2_UNREAD_MSG == cmdId)
    {
        NSDictionary* msgDict = (NSDictionary*)data;
        NSArray* unReadMsgArray = [msgDict objectForKey:@"msgArray"];
        if(!unReadMsgArray || unReadMsgArray.count < 1)
            return;
        
        DDMessageModule* moduleMessage = getDDMessageModule();
        NSString* sId;
        for(NSUInteger i = [unReadMsgArray count]; i > 0; --i)
        {
            MessageEntity* msg = [unReadMsgArray objectAtIndex:i-1];
            sId = msg.sessionId;
            //先清空下未读消息，服务器端会再次送过来
            if(i == [unReadMsgArray count])
            {
                [moduleMessage removeArrayMessage:sId];
            }
            //判断是否是在屏蔽列表中
            if (![[[DDSetting instance] getShieldSessionIDs] containsObject:msg.sessionId])
            {
                [moduleMessage pushMessage:msg.sessionId message:msg];
            }
            else
            {
                //插入数据库，并发送已读确认
                [[DDDatabaseUtil instance] insertMessage:msg
                                                 success:^{
                                                     
                                                 } failure:^(NSString *errorDescripe) {
                                                     DDLog(@"%@",errorDescripe);
                                                 }];
                SessionEntity* session = [self getSessionBySId:sId];
                [self tcpSendReadedAck:session];
            }
        }
        //如果离线消息的用户信息不存在，则需要获取
        DDUserlistModule* moduleUserlist = getDDUserlistModule();
        if(![moduleUserlist isContianUser:sId])
        {
            DDUserlistModule* moduleUserlist = getDDUserlistModule();
            [moduleUserlist tcpGetUnkownUserInfo:sId];
            return;
        }

        //如果会话不存在，则创建
        if(![self isContianSession:sId])
        {
            [self createSingleSession:sId];
        }
        SessionEntity* session = [self getSessionBySId:sId];
        session.lastSessionTime = time(0);
        //排序
        [self sortRecentlySessions];
        [self uiAsyncNotify:MKN_DDSESSIONMODULE_RECENTLYLIST userInfo:nil];
        
        NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:sId forKey:USERINFO_SID];
        [self uiAsyncNotify:MKN_DDSESSIONMODULE_SINGLEMSG userInfo:userInfo];

    }
    else if(CMD_MSG_GET_2_HISTORY_MSG == cmdId)
    {
        NSDictionary* msgDict = (NSDictionary*)data;
        NSArray* historyMsgArray = [msgDict objectForKey:@"msgArray"];
        NSString* sId = [msgDict objectForKey:@"sessionId"];
        
        /*if(!historyMsgArray || historyMsgArray.count < 1) {
            return;
        }*/
        
        
        DDMessageModule* moduleMessage = getDDMessageModule();
        for(NSUInteger i = [historyMsgArray count]; i > 0; --i)
        {
            MessageEntity* msg = [historyMsgArray objectAtIndex:i-1];
            [moduleMessage pushMessage:sId message:msg];
        }
        NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:sId forKey:USERINFO_SID];
        [self uiAsyncNotify:MKN_DDSESSIONMODULE_HISTORYMSG userInfo:userInfo];
    }
    else if(CMD_MSG_DATA_ACK == cmdId)
    {
        [self sortRecentlySessions];
        [self uiAsyncNotify:MKN_DDSESSIONMODULE_RECENTLYLIST userInfo:nil];
    
        NSNumber* no = (NSNumber*)data;
        DDMessageModule* moduleMessage = getDDMessageModule();
        [moduleMessage ackSendMsg:[no intValue]];
    }
}

-(SessionEntity*)getSessionBySId:(NSString*)sId
{
    @synchronized(self)
    {
        return [_allSessions valueForKey:sId];
    }
}

-(BOOL)isContianSession:(NSString*)sId
{
    return ([_allSessions valueForKey:sId] != nil);
}

-(SessionEntity *)createSessionEntity:(NSString *)uid avatar:(NSString *)avatar uname:(NSString *)uname userType:(uint16)userType{
    SessionEntity* newSession = [self getSessionBySId:uid];
    if(newSession)
        return newSession;
    SessionEntity* session = [[SessionEntity alloc] init];
    session.type = SESSIONTYPE_SINGLE;
    session.sessionId = uid;

    DDUserlistModule* userModule = getDDUserlistModule();
    UserEntity* user = [userModule getUserById:uid];
    session.lastSessionTime = user.userUpdated;
    @synchronized(self)
    {
        [_allSessions setObject:session forKey:uid];
        if (![_recentlySessionIds containsObject:uid])
        {
            [_recentlySessionIds addObject:uid];
        }
    }
    
    return session;
}

-(SessionEntity*)createSingleSession:(NSString*)sId
{

    __block SessionEntity* newSession = nil;
//    [[DDSundriesCenter instance] pushTaskToSynchronizationSerialQUeue:^{
        newSession = [self getSessionBySId:sId];
        if(newSession)
        {
            if (![_recentlySessionIds containsObject:sId])
            {
                if (sId)
                {
                    [_recentlySessionIds addObject:sId];
                }
            }
            return newSession;
        }
        newSession = [[SessionEntity alloc] init];
        newSession.type = SESSIONTYPE_SINGLE;
        newSession.sessionId = sId;
        UserEntity* user = [getDDUserlistModule() getUserById:sId];
        newSession.lastSessionTime = user.userUpdated;
        @synchronized(self)
        {
            if (sId)
            {
                [_allSessions setObject:newSession forKey:sId];
            }
            if (![_recentlySessionIds containsObject:sId])
            {
                [_recentlySessionIds addObject:sId];
            }
        }
        
        return newSession;
//    }];
//    return newSession;
}

-(SessionEntity*)createGroupSession:(NSString*)sId type:(int)type
{
    SessionEntity* newSession = [self getSessionBySId:sId];
    if(newSession)
    {
        if (![_recentlySessionIds containsObject:sId]) {
            [_recentlySessionIds addObject:sId];

        }
        return newSession;
    }
    SessionEntity* session = [[SessionEntity alloc] init];
    if (type == 1)
    {
        session.type = SESSIONTYPE_GROUP;
    }
    else if (type == 2)
    {
        session.type = SESSIONTYPE_TEMP_GROUP;
    }
    session.sessionId = sId;
    session.lastSessionTime = [[NSDate date] timeIntervalSince1970];
    @synchronized(self)
    {
        [_allSessions setObject:session forKey:sId];
        if (![_recentlySessionIds containsObject:sId])
        {
            [_recentlySessionIds addObject:sId];
        }
    }
    
    return session;
}

-(void)sortRecentlySessions
{
    @autoreleasepool {
        NSArray* topSessions = [[DDSetting instance] getTopSessionIDs];
        NSMutableArray* recentlySessionIds = [[NSMutableArray alloc] initWithArray:topSessions];
        if (!recentlySessionIds)
        {
            recentlySessionIds = [[NSMutableArray alloc] init];
        }
        [_recentlySessionIds removeObjectsInArray:recentlySessionIds];
        if([_recentlySessionIds count] > 1)
        {
            [_recentlySessionIds sortUsingComparator:
             ^NSComparisonResult(NSString* sId1, NSString* sId2)
             {
                 SessionEntity* session1 = [self getSessionBySId:sId1];
                 SessionEntity* session2 = [self getSessionBySId:sId2];
                 if(session1.lastSessionTime > session2.lastSessionTime)
                     return NSOrderedAscending;
                 else if(session1.lastSessionTime < session2.lastSessionTime)
                     return NSOrderedDescending;
                 else
                     return NSOrderedSame;
             }];
        }
        [recentlySessionIds addObjectsFromArray:_recentlySessionIds];
        _recentlySessionIds = recentlySessionIds;
    
        NSString *npcUserId = nil;
        DDUserlistModule* userListModule = getDDUserlistModule();
        for(int index = 0; index < [_recentlySessionIds count]; index ++)
        {
            NSString* sessionID = _recentlySessionIds[index];
            SessionEntity* session = [self getSessionBySId:sessionID];
            if (!session)
            {
                if ([sessionID hasPrefix:@"group"])
                {
                    DDGroupModule* groupModule = getDDGroupModule();
                    GroupEntity* group = [groupModule getGroupByGId:sessionID];
                    if (group)
                    {
                        [self createGroupSession:group.groupId type:group.groupType];
                    }
                }
                else
                {
                    [self createSingleSession:sessionID];
                }
//                [_recentlySessionIds removeObject:sessionID];
            }
//            if (!session)
//            {
//                if ([sesionID hasPrefix:@"group"])
//                {
//                    DDGroupInfoAPI* groupInfoAPI = [[DDGroupInfoAPI alloc] init];
//                    [groupInfoAPI requestWithObject:[sesionID substringFromIndex:[GROUP_PRE length]] Completion:^(id response, NSError *error) {
//                        if (!error)
//                        {
//                            if (response)
//                            {
//                                [[DDSundriesCenter instance] pushTaskToSynchronizationSerialQUeue:^{
//                                    DDGroupModule* groupModule = getDDGroupModule();
//                                    [groupModule addGroup:response];
//                                    [self createGroupSession:sesionID type:[(GroupEntity*)response groupType]];
//                                    [self sortRecentlySessions];
//                                }];
//
//                            }
//                        }
//                        else
//                        {
//                            [_recentlySessionIds removeObject:sesionID];
//                            [[DDSetting instance] removeTopSessionID:sesionID];
//                        }
//                    }];
//                }
//                else
//                {
//                    DDUserInfoAPI* userInfoAPI = [[DDUserInfoAPI alloc] init];
//                    [userInfoAPI requestWithObject:@[sesionID] Completion:^(id response, NSError *error) {
//                        if (!error)
//                        {
//                            [self createSingleSession:sesionID];
//                            [[DDSundriesCenter instance] pushTaskToSynchronizationSerialQUeue:^{
//                                DDUserlistModule* userModule = getDDUserlistModule();
//                                [userModule addUser:response[0]];
//                                [self sortRecentlySessions];
//                            }];
//                        }
//                        else
//                        {
//                            [_recentlySessionIds removeObject:sesionID];
//                            [[DDSetting instance] removeTopSessionID:sesionID];
//                        }
//                    }];
//                }
//                return;
//            }
            UserEntity *tempUser = [userListModule getUserById:sessionID];

            if (tempUser) {
                if((tempUser.userRole & 0x20000000) != 0){
                    npcUserId=sessionID ;
                    
                }
            }
        }
        
        if (npcUserId) {
            [_recentlySessionIds removeObject:npcUserId];
            [_recentlySessionIds insertObject:npcUserId atIndex:0];
        }
    }
}

-(void)sortAllGroupUsers
{
    @synchronized(self)
    {
        for(NSString* sId in _allSessions)
        {
            SessionEntity* session = [_allSessions objectForKey:sId];
            if(SESSIONTYPE_GROUP == session.type)
                [session sortGroupUsers];
        }
    }
}

-(void)tcpSendReadedAck:(SessionEntity*)session
{
    
    if (session.type == SESSIONTYPE_SINGLE)
    {
        DDUserMsgReadACKAPI* userMsgReadAck = [[DDUserMsgReadACKAPI alloc] init];
        [userMsgReadAck requestWithObject:session.sessionId Completion:nil];
    }
    else
    {
        DDGroupMsgReadACKAPI* groupMsgReadAck = [[DDGroupMsgReadACKAPI alloc] init];
        [groupMsgReadAck requestWithObject:session.orginId Completion:nil];
        
    }
}

-(NSArray *)getAllSessions{
    return [_allSessions allValues];
}

-(NSString*)getLastSession
{
    //因为npc的lastSessionTime是最大的所以这里要把npc排除在外
    NSString* lastSessionID = nil;
    NSInteger updateTime = 0;
    for (NSString* sessionID in _recentlySessionIds)
    {
        DDSessionModule* sessionModule = getDDSessionModule();
        SessionEntity* session = [sessionModule getSessionBySId:sessionID];
        UserEntity* user = [getDDUserlistModule() getUserById:session.orginId];
        if ((user.userRole & 0x20000000) != 0)
        {
            continue;
        }
        if (session.lastSessionTime > updateTime)
        {
            updateTime = session.lastSessionTime;
            lastSessionID = session.sessionId;
        }
    }
    return lastSessionID;
}

-(void)addSession:(SessionEntity*)session
{
    @autoreleasepool {
        [_allSessions setObject:session forKey:session.sessionId];
    }
//    [_recentlySessionIds addObject:session.sessionId];
}
#pragma mark PrivateAPI
- (void)n_receiveReceiveMessageNotification:(NSNotification*)notification
{
    //如果消息的用户信息不存在，则需要获取
    MessageEntity* msg = [notification object];
    [[DDSundriesCenter instance] pushTaskToSynchronizationSerialQUeue:^{
        
        if(![self.recentlySessionIds containsObject:msg.sessionId])
        {
            if(MESSAGE_TYPE_GROUP == msg.msgType || MESSAGE_TYPE_TEMP_GROUP ==msg.msgType)
            {
                DDGroupModule* groupModule = getDDGroupModule();
                GroupEntity* group = [groupModule getGroupByGId:msg.orginId];
                if (group)
                {
                    [self createGroupSession:msg.sessionId type:msg.msgType];
                    [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:msg.sessionId];
                }
                else
                {
                    DDGroupInfoAPI* groupInfoAPI = [[DDGroupInfoAPI alloc] init];
                    [groupInfoAPI requestWithObject:msg.sessionId Completion:^(id response, NSError *error) {
                        if (!error)
                        {
                            if (response)
                            {
                                [groupModule addGroup:response];
                                [self createGroupSession:msg.sessionId type:msg.msgType];
                                [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:msg.sessionId];
                            }
                        }
                    }];
                }
            }
            else
            {
                DDUserlistModule* userModule = getDDUserlistModule();
                UserEntity* user = [userModule getUserById:msg.orginId];
                if (user)
                {
                    [self createSingleSession:msg.sessionId];
                    [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:msg.sessionId];
                }
                else
                {
                    DDUserInfoAPI* userInfoAPI = [[DDUserInfoAPI alloc] init];
                    [userInfoAPI requestWithObject:msg.orginId Completion:^(id response, NSError *error) {
                        if (!error)
                        {
                            [userModule addUser:response];
                            [self createSingleSession:msg.sessionId];
                            [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:msg.sessionId];
                        }
                    }];
                }
            }
        }
        else
        {
            SessionEntity* session = [self getSessionBySId:msg.sessionId];
            session.lastSessionTime = [[NSDate date] timeIntervalSince1970];
            [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:nil];
        }
    }];

}

#pragma mark KVO

@end
