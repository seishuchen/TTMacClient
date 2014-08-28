/************************************************************
 * @file         DDLoginModule.m
 * @author       快刀<kuaidao@mogujie.com>
 * summery       登陆模块
 ************************************************************/

#import "DDLoginModule.h"
#import "LoginHandler.h"
#import "LoginEntity.h"
#import "UserEntity.h"
#import "DDLoginWindowController.h"
#import "DDDictionaryAdditions.h"
#import "NSEvent+DDEventAdditions.h"
#import "DDHttpUtil.h"
#import "DDHttpModule.h"
#import "DDUserListModule.h"
#import "TcpProtocolPack.h"
#import "CrashReportManager.h"

static NSString* const keyLastLoginUserName = @"DDLOGINMODULE_LASTLOGINNAME";
static NSString* const keyLastLoginUserPassword = @"DDLOGINMODULE_LASTLOGINPASS";
static NSString* const keyLastLoginUserAvatar = @"DDLOGINMODULE_LASTLOGINAVATAR";

DDLoginModule* getDDLoginModule()
{
    return (DDLoginModule*)[[DDLogic instance] queryModuleByID:MODULE_ID_LOGIN];
}

@interface DDLoginModule()

-(void)onHandleTcpData:(uint16)cmdId data:(id)data;

@end

@implementation DDLoginModule

-(id) initModule
{
    if(self = [super initModule:MODULE_ID_LOGIN])
    {
    }
    return self;
}



#pragma mark TcpHandle
-(void)onHandleTcpData:(uint16)cmdId data:(id)data
{
//    if(CMD_LOGIN_RES_USERLOGIN == cmdId)
//    {
//        LoginEntity* logEntity = (LoginEntity*)data;
//        
//        [[DDLogic instance] pushTaskWithBlock:^{
//            [[DDLogic instance] archive];
//        }];
//        
//        if (logEntity.result == 0)
//        {
//            [NotificationHelp postNotification:notificationLoginMsgServerSuccess userInfo:nil object:logEntity];
//        }
//    }
//    else if(CMD_LOGIN_RES_MSGSERVER == cmdId)
//    {
//        LoginEntity* logEntity = (LoginEntity*)data;
//        if(logEntity.result == 0)
//        {
//            //登录服务器成功
//            [NotificationHelp postNotification:notificationLoginLoginServerSuccess userInfo:nil object:logEntity];
//        }
//        else
//        {
//            //登录服务器失败
//            [NotificationHelp postNotification:notificationLoginLoginServerFailure userInfo:nil object:nil];
//        }
//    }
    if(CMD_LOGIN_KICK_USER == cmdId)
    {
        [NotificationHelp postNotification:notificationUserKickouted userInfo:nil object:nil];
    }
}


#pragma mark NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_lastLoginName forKey:keyLastLoginUserName];
    [aCoder encodeObject:_lastLoginPass forKey:keyLastLoginUserPassword];
    [aCoder encodeObject:_lastUseAvatar forKey:keyLastLoginUserAvatar];

}
- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = getDDLoginModule();
    _lastLoginName = [aDecoder decodeObjectForKey:keyLastLoginUserName];
    _lastLoginPass = [aDecoder decodeObjectForKey:keyLastLoginUserPassword];
    _lastUseAvatar = [aDecoder decodeObjectForKey:keyLastLoginUserAvatar];
    return self;
}
@end
