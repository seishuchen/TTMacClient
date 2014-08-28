
/************************************************************
 * @file         DDFriendlistModule.m
 * @author       快刀<kuaidao@mogujie.com>
 * summery       成员列表管理模块
 ************************************************************/

#import "DDUserlistModule.h"
#import "DDSessionModule.h"
#import "DDGroupModule.h"
#import "DDTcpLinkModule.h"
#import "UserListHandler.h"
#import "UserEntity.h"
#import "GroupEntity.h"
#import "DDKeychain.h"
#import "TcpProtocolPack.h"
#import "DDLogic.h"
#import "SpellLibrary.h"
#import "SessionEntity.h"
#import "StateMaintenanceManager.h"
#import "DDTcpClientManager.h"
#import "DDUserInfoAPI.h"

static NSInteger const getAllUsersTimeout = 5;

DDUserlistModule* getDDUserlistModule()
{
    return (DDUserlistModule*)[[DDLogic instance] queryModuleByID:MODULE_ID_FRIENDLIST];
}

@interface DDUserlistModule(PrivateAPI)

-(void)onHandleTcpData:(uint16)cmdId data:(id)data;
//-(void)syncStatusToUserlist;
-(void)offlineAllUserlist;

- (void)n_receiveGetAllUsersNotification:(NSNotification*)notification;

@end

@implementation DDUserlistModule
{
    NSArray* _ignoreUserList;
}
-(id) initModule
{
    if(self = [super initModule:MODULE_ID_FRIENDLIST])
    {
        _allUsers = [[NSMutableDictionary alloc ] init];
        _ignoreUserList = @[@"1szei2"];
    }
    return self;
}

-(void)onLoadModule
{
    [[DDLogic instance] addObserver:MODULE_ID_TCPLINK name:MKN_DDTCPLINKMODULE_DISCONNECTED observer:self selector:@selector(onTcplinkDisconnected:)];
}

#pragma mark Public

-(BOOL)isInIgnoreUserList:(NSString*)userID
{
    if ([_ignoreUserList containsObject:userID])
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

-(void)addUser:(UserEntity*)newUser
{
    if (newUser)
    {
        if (newUser.userUpdated == 0)
        {
            if (![[_allUsers allKeys] containsObject:newUser.userId])
            {
                [_allUsers setObject:newUser forKey:newUser.userId];
            }
        }
        else
        {
            [_allUsers setObject:newUser forKey:newUser.userId];
        }
    }
}

-(void)setOrganizationMembers:(NSArray*)users
{
    if (_organizationMembers)
    {
        _organizationMembers = nil;
    }
    _organizationMembers = users;
}

- (NSArray*)getAllUsers
{
    NSMutableArray* allUsers = [[NSMutableArray alloc] init];
    [_allUsers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
//        if ([[(UserEntity*)obj name] isEqualToString:@"千凡"])
//        {
//            DDLog(@"asd");
//        }
        [allUsers addObject:obj];
    }];
    return allUsers;
}
- (NSArray*)getAllOrganizationMembers
{
    return _organizationMembers;
}

#pragma mark TcpHandle
-(void)onHandleTcpData:(uint16)cmdId data:(id)data
{
    
    if (CMD_FRI_USERLIST_ONLINE_STATE == cmdId)
    {
        //获得最近联系人在线状态
        NSDictionary* dictStatus = (NSDictionary*)data;
        [[StateMaintenanceManager instance] mergerUsersOnlineState:dictStatus];
    }
    else if(CMD_FRI_USER_STATE_CHANGE == cmdId)
    {
        //联系人在线状态变更通知
        NSDictionary* dictStatus = (NSDictionary*)data;
        [[StateMaintenanceManager instance] mergerUsersOnlineState:dictStatus];
    }
    else if(CMD_FRI_USER_INFO_LIST == cmdId)
    {
        NSArray* unkownUsers = (NSArray*)data;
        for (UserEntity *user in unkownUsers)
        {
            [self addUser:user];
        }
        
        //trick 如果是个用户的话表示是，获取陌生人信息过来的动作而不是获取leftUsers过来的请求
        if(1 == unkownUsers.count)
        {
            UserEntity* user = [unkownUsers objectAtIndex:0];
            NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithObject:user.userId forKey:USERINFO_SID];
            [self uiAsyncNotify:MKN_DDSESSIONMODULE_SINGLEMSG userInfo:userInfo];
        }
    }
    else if (CMD_FRI_LIST_STATE_RES == cmdId)
    {
        NSDictionary* dictionary = (NSDictionary*)data;
        [[StateMaintenanceManager instance] mergerUsersOnlineState:dictionary];
    }
    else if (CMD_FRI_REMOVE_SESSION_RES == cmdId)
    {
        NSDictionary* response = (NSDictionary*)data;
        
        int result = [response[@"result"] intValue];
        if (result != 0)
        {
            return;
        }
        
        int sessionType = [response[@"sessionType"] intValue];
        NSString* sessionID;
        switch (sessionType)
        {
            case 1:
                sessionID = response[@"sessionId"];
                break;
            case 2:
                sessionID = [NSString stringWithFormat:@"group_%@",response[@"sessionId"]];
            default:
                break;
        }
        
        //刷新最近联系人列表
        DDSessionModule* sessionModule = getDDSessionModule();
        [sessionModule.recentlySessionIds removeObject:sessionID];
        [NotificationHelp postNotification:notificationRemoveSession userInfo:nil object:sessionID];
    }
}

//tcp连接断开
-(void)onTcplinkDisconnected:(NSNotification *)notification
{
    [self offlineAllUserlist];
}

-(void)offlineAllUserlist
{
    [[StateMaintenanceManager instance] offlineAllUser];
}



-(UserEntity*)myUser
{
    return [_allUsers objectForKey:self.myUserId];
}

-(BOOL)isContianUser:(NSString*)uId
{
     return ([_allUsers valueForKey:uId] != nil);
}

-(UserEntity *)getUserById:(NSString *)uid
{
    return [_allUsers objectForKey:uid];
}

-(void)tcpGetUnkownUserInfo:(NSString*)uId
{
    NSMutableArray* unknowUserArray = [[NSMutableArray alloc] init];
    [unknowUserArray addObject:uId];
    [[DDLogic instance] pushTaskWithBlock:
     ^
     {
         NSMutableData* data = [TcpProtocolPack getUserInfoListReq:unknowUserArray];
         [[DDTcpClientManager instance] writeToSocket:data];
     }];
}

-(NSString *)passwordForUserName:(NSString *)userName{
    NSError *error =nil;
    DDKeychain *keychain = [DDKeychain defaultKeychain_error:&error];
    NSString *password = [keychain internetPasswordForServer:@"duoduo" account:userName protocol:FOUR_CHAR_CODE('DDIM') error:&error ];
    if (error) {
        OSStatus err = (OSStatus)[error code];
        NSDictionary *userInfo = [error userInfo];
        DDLog(@"could not retrieve password for account %@: %@ returned %ld (%@)",userName, [userInfo objectForKey:AIKEYCHAIN_ERROR_USERINFO_SECURITYFUNCTIONNAME], (long)err, [userInfo objectForKey:AIKEYCHAIN_ERROR_USERINFO_ERRORDESCRIPTION]);
    }
    return  password;
}

- (void)setPassword:(NSString *)inPassword forUserName:(NSString *)userName
{
	NSError *error = nil;
	[[DDKeychain defaultKeychain_error:&error] setInternetPassword:inPassword
														 forServer:@"duoduo"
														   account:userName
														  protocol:FOUR_CHAR_CODE('DDIM')
															 error:&error];
	if (error) {
		OSStatus err = (OSStatus)[error code];
		/*errSecItemNotFound: no entry in the keychain. a harmless error.
		 *we don't ignore it if we're trying to set the password, though (because that would be strange).
		 *we don't get here at all for noErr (error will be nil).
		 */
		if (inPassword || (err != errSecItemNotFound)) {
			NSDictionary *userInfo = [error userInfo];
			DDLog(@"could not %@ password for account %@: %@ returned %ld (%@)", inPassword ? @"set" : @"remove", userName, [userInfo objectForKey:AIKEYCHAIN_ERROR_USERINFO_SECURITYFUNCTIONNAME], (long)err, [userInfo objectForKey:AIKEYCHAIN_ERROR_USERINFO_ERRORDESCRIPTION]);
		}
	}
}

- (void)getUserInfoWithUserID:(NSString*)userID completion:(GetUserInfoCompletion)completion
{
    UserEntity* user = [self getUserById:userID];
    if (user)
    {
        completion(user);
        return;
    }
    DDUserInfoAPI* userInfoAPI = [[DDUserInfoAPI alloc] init];
    [userInfoAPI requestWithObject:@[userID] Completion:^(id response, NSError *error) {
        if (!error)
        {
            [self addUser:response[0]];
            completion(response[0]);
        }
        else
        {
            DDLog(@"error%@ userID:%@",[error domain],userID);
            [self getUserInfoWithUserID:userID completion:completion];
        }
    }];
}

#pragma mark PrivateAPI
@end
