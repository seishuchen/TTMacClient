//
//  DDLoginManager.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-5.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDLoginManager.h"
#import "DDHttpServer.h"
#import "DDTokenManager.h"
#import "DDMsgServer.h"
#import "DDTcpServer.h"
#import "DDLoginServer.h"
#import "LoginEntity.h"
#import "UserEntity.h"
#import "DDReceiveKickAPI.h"
@interface DDLoginManager(privateAPI)

- (void)p_registerAPI;
- (void)reloginAllFlowSuccess:(void(^)())success failure:(void(^)())failure;

@end

@implementation DDLoginManager
{
    NSString* _lastLoginUser;       //最后登录的用户ID
    NSString* _lastLoginPassword;
    NSString* _lastLoginUserName;
    NSString* _dao;
    
    BOOL _relogining;
}
+ (instancetype)instance
{
    static DDLoginManager *g_LoginManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_LoginManager = [[DDLoginManager alloc] init];
    });
    return g_LoginManager;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _httpServer = [[DDHttpServer alloc] init];
        _tokenServer = [[DDTokenManager alloc] init];
        _msgServer = [[DDMsgServer alloc] init];
        _tcpServer = [[DDTcpServer alloc] init];
        _loginServer = [[DDLoginServer alloc] init];
        _relogining = NO;
        [self p_registerAPI];
    }
    return self;
}

- (NSString*)token
{
    return [_tokenServer.token copy];
}

#pragma mark Public API
- (void)loginWithUsername:(NSString*)name password:(NSString*)password success:(void(^)(UserEntity* loginedUser))success failure:(void(^)(NSString* error))failure
{
    //先登录Http Server
    [_httpServer loginWithUserName:name password:password success:^(id respone) {
        NSString* token = respone[@"data"][@"token"];
        NSString *userId = respone[@"data"][@"userId"];
        NSString *dao = respone[@"data"][@"dao"];

        _tokenServer.token = token;
        _tokenServer.dao = dao;
        _lastLoginUser = userId;
        _lastLoginUserName = [name copy];
        _lastLoginPassword = [password copy];
        _dao = dao;
        
        UserEntity* user = [[UserEntity alloc] init];
        user.userId = userId;
        
        //连接登录服务器
        [_tcpServer loginTcpServerIP:SERVER_IP port:SERVER_PORT Success:^{
            //获取消息服务器ip
            [_loginServer connectLoginServerSuccess:^(LoginEntity *loginEntity) {
                [_tcpServer loginTcpServerIP:loginEntity.ip2 port:loginEntity.port Success:^{
                    //连接消息服务器
                    [_msgServer checkUserID:userId token:token success:^(id object) {
                        //登录完成,开启自动刷新Token
                        LoginEntity* resultLogin = (LoginEntity*)object;
                        user.name = resultLogin.myUserInfo.name;
                        user.avatar = resultLogin.myUserInfo.avatar;
                        user.userRole = resultLogin.myUserInfo.userRole;
                        [_tokenServer startAutoRefreshToken];
                        success(user);
                    } failure:^(id object) {
                        DDLog(@"登录验证失败");
                        log4Error(@"登录验证失败");
                        failure(@"登录验证失败");
                    }];
                } failure:^{
                    DDLog(@"连接消息服务器出错");
                    log4Error(@"连接消息服务器出错");
                    failure(@"连接消息服务器出错");
                }];
            } failure:^{
                DDLog(@"获取消息服务器IP出错");
                log4Error(@"获取消息服务器IP出错");
                failure(@"获取消息服务器IP出错");
            }];
        } failure:^{
            DDLog(@"连接登录服务器失败");
            log4Error(@"连接登录服务器失败");
            failure(@"连接登录服务器失败");
        }];
    } failure:^(id error) {
        DDLog(@"%@",error);
        log4Error(@"%@",error);
        failure(error);
    }];
}

- (void)reloginSuccess:(void(^)())success failure:(void(^)(NSString* error))failure
{
    if (!_relogining)
    {
        DDLog(@"开始断线重连");
        log4Info(@"开始断线重连");
        _relogining = YES;
        [_tokenServer stopAutoRefreshToken];
        [_tcpServer loginTcpServerIP:SERVER_IP port:SERVER_PORT Success:^{
            //连接登录服务器
            [_loginServer connectLoginServerSuccess:^(LoginEntity *loginEntity) {
                [_tcpServer loginTcpServerIP:loginEntity.ip2 port:loginEntity.port Success:^{
                    //连接消息服务器
                    [_msgServer checkUserID:_lastLoginUser token:_tokenServer.token success:^(id object) {
                        //登录完成
                        [_tokenServer startAutoRefreshToken];
                        _relogining = NO;
                        log4Info(@"断线重连成功");
                        success(_lastLoginUser);
                    } failure:^(id object) {
                        DDLog(@"登录验证失败,尝试重走流程");
                        log4Error(@"登录验证失败,尝试重走流程");
                        [self reloginAllFlowSuccess:^{
                            
                            log4Info(@"断线重连成功");
                            _relogining = NO;
                            success();
                        } failure:^{
                            _relogining = NO;
                            failure(@"登录验证失败");
                        }];
                    }];
                } failure:^{
                    DDLog(@"连接消息服务器出错");
                    log4Error(@"连接消息服务器出错");
                    _relogining = NO;
                    failure(@"连接消息服务器出错");
                }];
            } failure:^{
                DDLog(@"连接登录服务器出错");
                log4Error(@"连接登录服务器出错");
                _relogining = NO;
                failure(@"连接登录服务器出错");
            }];
        } failure:^{
            DDLog(@"TCP连接失败");
            log4Error(@"TCP连接失败");
            _relogining = NO;
            failure(@"TCP连接失败");
        }];
    }

}

- (void)offlineCompletion:(void(^)())completion
{
    [_tcpServer disconnect];
    completion();
}

#pragma mark - PrivateAPI
- (void)reloginAllFlowSuccess:(void(^)())success failure:(void(^)())failure
{
    [self loginWithUsername:_lastLoginUserName password:_lastLoginPassword success:^(UserEntity *loginedUser) {
        success();
    } failure:^(NSString *error) {
        failure();
    }];
}

- (void)p_registerAPI
{
    DDReceiveKickAPI* api = [[DDReceiveKickAPI alloc] init];
    [api registerAPIInAPIScheduleReceiveData:^(id object, NSError *error) {
        [NotificationHelp postNotification:notificationUserKickouted userInfo:nil object:nil];
    }];
}

@end
