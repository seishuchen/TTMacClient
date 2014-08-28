//
//  DDClientState.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-14.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDClientState.h"

@interface DDClientState(PrivateAPI)

- (void)n_receiveTcpLinkDisconnectNotification:(NSNotification*)notification;
- (void)n_receiveUserLoginSuccessNotification:(NSNotification*)notification;
- (void)n_receiveUserInitiativeOfflineNotification:(NSNotification*)notification;

@end

@implementation DDClientState
+ (instancetype)instance
{
    static DDClientState* g_clientState;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_clientState = [[DDClientState alloc] init];
    });
    return g_clientState;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveTcpLinkDisconnectNotification:) name:notificationTcpLinkDisconnect object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveUserLoginSuccessNotification:) name:notificationUserLoginSuccess object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveUserInitiativeOfflineNotification:) name:notificationUserInitiativeOffline object:nil];
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationTcpLinkDisconnect object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationUserLoginSuccess object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:notificationUserInitiativeOffline object:nil];
}

#pragma mark - privateAPI
- (void)n_receiveTcpLinkDisconnectNotification:(NSNotification *)notification
{
    self.socketLink = NO;
    self.online = NO;
}

- (void)n_receiveUserLoginSuccessNotification:(NSNotification *)notification
{
    self.socketLink = YES;
    self.kickout = NO;
    self.userInitiativeOffline = NO;
    self.online = YES;
}

- (void)n_receiveUserInitiativeOfflineNotification:(NSNotification*)notification
{
    self.userInitiativeOffline = YES;
    self.online = NO;
}
@end
