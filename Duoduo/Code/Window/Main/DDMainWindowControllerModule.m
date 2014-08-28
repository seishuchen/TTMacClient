//
//  DDMainWindowControllerModule.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-15.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDMainWindowControllerModule.h"
#import "DDTcpClientManager.h"
#import "DDUserlistModule.h"
#import "UserEntity.h"
#import "DDMessageModule.h"
#import "DDGetOfflineFileAPI.h"
#import "FileTransfer.h"
@interface DDMainWindowControllerModule(privateAPI)

- (void)n_receiveReloginNotification:(NSNotification*)notification;

@end

@implementation DDMainWindowControllerModule

- (id)init
{
    self = [super init];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveReloginNotification:) name:notificationUserReloginSuccess object:nil];
    }
    return self;
}

#pragma mark - privateAPI
- (void)n_receiveReloginNotification:(NSNotification *)notification
{
    //登陆完成获取个人未读消息
    DDMessageModule* messageModule = getDDMessageModule();
    [messageModule fetchAllUnReadMessageCompletion:^(NSError *error) {
        if(!error)
        {
            [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:nil];
        }
    }];
    
    //获取离线文件
    DDGetOfflineFileAPI* getOfflineFileAPI = [[DDGetOfflineFileAPI alloc] init];
    [getOfflineFileAPI requestWithObject:nil Completion:^(id response, NSError *error) {
        if(!error)
        {
            NSMutableArray* entity = (NSMutableArray*)response;
            if ([entity count] > 0)
            {
                FileTransfer *fileTransfer = [FileTransfer defaultTransfer];
                [fileTransfer handleFileHasOfflineRes:entity];
            }
        }
        else
        {
            DDLog(@"error:%@",[error domain]);
        }
    }];
}
@end
