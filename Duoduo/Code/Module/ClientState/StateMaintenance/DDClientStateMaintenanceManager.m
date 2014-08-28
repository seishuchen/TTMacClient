//
//  DDClientStateMaintenanceManager.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-12.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDClientStateMaintenanceManager.h"
#import "DDTcpClientManager.h"
#import <Sparkle/SUUpdater.h>
#import "Reachability.h"
#import "DDClientState.h"
#import "DDLoginManager.h"
#import "DDAlertWindowController.h"
static NSInteger const heartBeatTimeinterval = 5;
static NSInteger const serverHeartBeatTimeinterval = 10;
static NSInteger const reloginTimeinterval = 10;

@interface DDClientStateMaintenanceManager(PrivateAPI)

- (void)p_handleHeartBeatTimer:(NSTimer*)timer;
- (void)n_receiveServerHeartBeat;
- (void)n_receiveReachabilityChangedNotification:(NSNotification*)notification;
- (void)p_handleReloginTimer:(NSTimer*)timer;
- (void)p_handleReserverHeartTimer:(NSTimer*)timer;
- (void)n_receiveUserLoginSuccessNotification:(NSNotification*)notification;
- (void)n_receiveUserKickoffNotification:(NSNotification*)notification;


@end

@implementation DDClientStateMaintenanceManager
{
    NSTimer* _sendHeartTimer;
    NSTimer* _reloginTimer;
    NSTimer* _serverHeartBeatTimer;
    
    BOOL _receiveServerHeart;
}
+ (instancetype)instance
{
    static DDClientStateMaintenanceManager* g_clientStateManintenanceManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_clientStateManintenanceManager = [[DDClientStateMaintenanceManager alloc] init];
    });
    return g_clientStateManintenanceManager;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveServerHeartBeat) name:notificationServerHeartBeat object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(n_receiveReachabilityChangedNotification:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveUserKickoffNotification:) name:notificationUserKickouted object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveUserLoginSuccessNotification:) name:notificationUserLoginSuccess object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveUserLoginSuccessNotification:) name:notificationUserReloginSuccess object:nil];
        
        Reachability * reach = [Reachability reachabilityWithHostname:@"www.baidu.com"];
        [reach startNotifier];
        
    }
    return self;
}

-(void)startHeartBeat{
 
    log4Info(@"begin heart beat");
    if (!_sendHeartTimer && ![_sendHeartTimer isValid])
    {
        _sendHeartTimer = [NSTimer scheduledTimerWithTimeInterval: heartBeatTimeinterval
                                                           target: self
                                                         selector: @selector(p_handleHeartBeatTimer:)
                                                         userInfo: nil
                                                          repeats: YES];
    }
}

- (void)stopHeartBeat
{
    if (_sendHeartTimer)
    {
        [_sendHeartTimer invalidate];
        _sendHeartTimer = nil;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationServerHeartBeat object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationUserLoginSuccess object:nil];
}

#pragma mark private API
-(void)p_handleHeartBeatTimer:(NSTimer *)timer{
    
    DDLog(@" *********嘣*********");
    NSMutableData *data = [TcpProtocolPack getHeartbeatRequestData];
    [[DDTcpClientManager instance] writeToSocket:data];
}

- (void)n_receiveServerHeartBeat
{
    _receiveServerHeart = YES;
}

- (void)n_receiveReachabilityChangedNotification:(NSNotification*)notification
{
    Reachability * reach = [notification object];
    
    if([reach isReachable])
    {
        //判断是否要断线重连
        DDLog(@"have network");
        log4Info(@"have network");
        
        [DDClientState instance].networkFine = YES;
        if (!_reloginTimer && [DDClientState instance].userID && ![_reloginTimer isValid])
        {
            _reloginTimer = [NSTimer scheduledTimerWithTimeInterval:reloginTimeinterval target:self selector:@selector(p_handleReloginTimer:) userInfo:nil repeats:YES];
            [_reloginTimer fire];
        }
    }
    else
    {
        //断网了
        //这里设置断网反应延时，为了那些经常断网的同学
        double delayInSeconds = 1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (![reach isReachable])
            {
                [[DDTcpClientManager instance] disconnect];
                [NotificationHelp postNotification:notificationUserOffline userInfo:nil object:nil];
            }
        });
        DDLog(@"have no network");
        log4Info(@"have no network");
    }
}

- (void)n_receiveUserLoginSuccessNotification:(NSNotification*)notification
{
    [self startHeartBeat];
    DDClientState* client = [DDClientState instance];
    
    if (!_serverHeartBeatTimer && !client.kickout && !client.userInitiativeOffline && !_reloginTimer && ![_reloginTimer isValid])
    {
        DDLog(@"begin maintenance _serverHeartBeatTimer");
        log4Info(@"begin maintenance _serverHeartBeatTimer")
        _serverHeartBeatTimer = [NSTimer scheduledTimerWithTimeInterval:serverHeartBeatTimeinterval target:self selector:@selector(p_handleReserverHeartTimer:) userInfo:nil repeats:YES];
        [_serverHeartBeatTimer fire];
    }
}

- (void)n_receiveUserKickoffNotification:(NSNotification*)notification
{
    [DDClientState instance].kickout = YES;
    [[DDTcpClientManager instance] disconnect];
    [NotificationHelp postNotification:notificationUserOffline userInfo:nil object:nil];
    [self stopHeartBeat];
}

- (void)p_handleReserverHeartTimer:(NSTimer*)timer
{
    DDLog(@"check server heart");
    log4Info(@"check server heart");
    if (_receiveServerHeart)
    {
        _receiveServerHeart = NO;
    }
    else
    {
        [_serverHeartBeatTimer invalidate];
        _serverHeartBeatTimer = nil;
        
        [[DDTcpClientManager instance] disconnect];
        [NotificationHelp postNotification:notificationUserOffline userInfo:nil object:nil];
        //开始重连
        DDLog(@"begin relogin");
        log4Info(@"begin relogin");
        DDClientState* clientState = [DDClientState instance];
        if (!_reloginTimer && ![_reloginTimer isValid] && clientState.userID && !clientState.kickout && !clientState.userInitiativeOffline)
        {
            _reloginTimer = [NSTimer scheduledTimerWithTimeInterval:reloginTimeinterval target:self selector:@selector(p_handleReloginTimer:) userInfo:nil repeats:YES];
            [_reloginTimer fire];
        }
    }
}

- (void)p_handleReloginTimer:(NSTimer*)timer
{
    DDClientState* clientState = [DDClientState instance];
    //TODO:这里可以判断|clientState|中的在线状态，但是socket断开之后，状态没有转为离线，所以还需要优化
    if (!clientState.kickout && !clientState.userInitiativeOffline)
    {
        [self stopHeartBeat];
        [[DDLoginManager instance] reloginSuccess:^{
            [_reloginTimer invalidate];
            _reloginTimer = nil;
            clientState.online = YES;
            [NotificationHelp postNotification:notificationUserReloginSuccess userInfo:nil object:nil];
            DDLog(@"relogin success");
            log4Info(@"relogin success");
        } failure:^(NSString *error) {
            DDLog(@"relogin failure:%@",error);
            log4Info(@"relogin failure:%@",error);
        }];
    }
    else
    {
        [_reloginTimer invalidate];
        _reloginTimer = nil;
    }
}

@end
