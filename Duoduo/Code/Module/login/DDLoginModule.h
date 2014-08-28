/************************************************************
 * @file         DDLoginModule.h
 * @author       快刀<kuaidao@mogujie.com>
 * summery       登陆模块
 ************************************************************/

#import <Foundation/Foundation.h>
#import "DDLogic.h"

//module key names
//static NSString* const MKN_DDLOGINMODULE_LOGINRESPONSE = @"DDLOGINMODULE_LOGINRESPONSE";        //TCP服务器登陆
//static NSString* const MKN_DDLOGINMODULE_RELOGINRESPONSE = @"DDLOGINMODULE_RELOGINRESPONSE";    //断线重连登陆响应
//static NSString* const MKN_DDLOGINMODULE_LOGINCOMPETED = @"DDLOGINMODULE_LOGINCOMPLETED";       //登陆完成通知
//static NSString* const MKN_DDLOGINMODULE_LASTLOGINNAME = @"DDLOGINMODULE_LASTLOGINNAME";        //最后登录用户名
//static NSString* const MKN_DDLOGINMODULE_LASTLOGINPASS = @"DDLOGINMODULE_LASTLOGINPASS";        //最后登录密码
//static NSString* const MKN_DDLOGINMODULE_LASTLOGINAVATAR = @"DDLOGINMODULE_LASTLOGINAVATAR";
//static NSString* const MKN_DDLOGINMODULE_KICKOUT = @"DDLOGINMODULE_KICKOUT";                    //踢除用户

@class DDLoginWindowController;
@class ReloginManager;
@interface DDLoginModule : DDTcpModule<NSCoding>
{
    DDLoginWindowController*    _loginWindowController;
}
@property(nonatomic,strong)NSString* lastLoginName; //临时放在这里存储用户名
@property(nonatomic,strong)NSString* lastLoginPass; //临时放在这里存储密码
@property(nonatomic,strong)NSString* lastUseAvatar; //临时放在这里存储用户头像

-(id) initModule;
-(void)relogin:(BOOL)force status:(uint32)status;

@end

extern DDLoginModule* getDDLoginModule();