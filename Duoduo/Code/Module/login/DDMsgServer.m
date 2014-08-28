//
//  DDMsgServer.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-5.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDMsgServer.h"
#import "LoginEntity.h"
#import "DDTcpClientManager.h"
#import "DDLoginAPI.h"
#import "LoginEntity.h"
static int const timeOutTimeInterval = 10;

typedef void(^Success)(id object);
typedef void(^Failure)(id object);

@interface DDMsgServer(PrivateAPI)

- (void)n_receiveLoginMsgServerNotification:(NSNotification*)notification;
- (void)n_receiveLoginLoginServerNotification:(NSNotification*)notification;

@end

@implementation DDMsgServer
{
    Success _success;
    Failure _failure;
    
    BOOL _connecting;
    NSUInteger _connectTimes;
}
- (id)init
{
    self = [super init];
    if (self)
    {
        _connecting = NO;
        _connectTimes = 0;
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveLoginMsgServerNotification:) name:notificationLoginMsgServerSuccess object:nil];
    }
    return self;
}

-(void)checkUserID:(NSString*)userID token:(NSString*)token success:(void(^)(id object))success failure:(void(^)(id object))failure
{
    
    if (!_connecting)
    {
        NSString *clientVersion = [NSString stringWithFormat:@"MAC/%@-%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];

        
        NSArray* parameter = @[userID,token,clientVersion,[NSNumber numberWithInteger:USER_STATUS_ONLINE]];
        
        DDLoginAPI* api = [[DDLoginAPI alloc] init];
        [api requestWithObject:parameter Completion:^(id response, NSError *error) {
            if (!error)
            {
                LoginEntity* loginEntity = (LoginEntity*)response;
                if (loginEntity.result == 0)
                {
                    success(response);
                }
                else
                {
                    NSError* newError = [NSError errorWithDomain:@"登录验证失败" code:6 userInfo:nil];
                    failure(newError);
                }
            }
            else
            {
                DDLog(@"error:%@",[error domain]);
                failure(error);
            }
        }];
    }
    
//    if (!_connecting)
//    {
//        _connectTimes ++;
//        DDLog(@"connectMsgServer:%@,token:%@",userID,token);
//        
//        NSString *clientVersion = [NSString stringWithFormat:@"MAC/%@-%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
//        NSMutableData *data =[TcpProtocolPack getLoginRequestData:userID token:token online:USER_STATUS_ONLINE clientVersion:clientVersion];
//        DDLog(@"--client version : %@",clientVersion);
//        [[DDTcpClientManager instance] writeToSocket:data];
//        
//        _success = [success copy];
//        _failure = [failure copy];
//        _connecting = YES;
//        
//        NSUInteger nowTimes = _connectTimes;
//        
//        double delayInSeconds = timeOutTimeInterval;
//        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
//        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//            if (_connecting && nowTimes == _connectTimes)
//            {
//                DDLog(@"connect msgServer timeout");
//                log4Info(@"connect msgServer timeout token:%@",token);
//                _connecting = NO;
//                failure(nil);
//            }
//        });
//    }
}

//- (void)n_receiveLoginMsgServerNotification:(NSNotification *)notification
//{
//    _connecting = NO;
//    id object = [notification object];
//    if (object)
//    {
//        _success(object);
//    }
//    else
//    {
//        _failure(object);
//    }
//}

@end
