//
//  DDRecentContactsModule.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-29.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDRecentContactsModule.h"
#import "DDRecentConactsAPI.h"
#import "DDRecentGroupAPI.h"
#import "DDUserlistModule.h"
#import "DDGroupModule.h"
#import "UserEntity.h"
#import "GroupEntity.h"
#import "SessionEntity.h"
#import "DDSessionModule.h"
#import "DDUnreadMessageUserAPI.h"
#import "DDUsersUnreadMessageAPI.h"
#import "DDGetOfflineFileAPI.h"
#import "FileTransfer.h"
#import "SpellLibrary.h"
#import "DDPathHelp.h"
#import "DDSetting.h"
#import "DDGroupInfoAPI.h"
#import "DDUserInfoAPI.h"

#define RECETNT_CONTACTS_PLIST_FILE                 @"RecentPerson.plist"

typedef void(^RecentUsersCompletion)();
typedef void(^RecentGroupCompletion)();
typedef void(^LoadTopSessionCompletion)();


@interface DDRecentContactsModule(PrivateAPI)

- (void)p_loadRecentUsers:(RecentUsersCompletion)completion;
- (void)p_loadRecentGroups:(RecentGroupCompletion)completion;

- (void)p_mergerUsersAndGroups;


- (NSString*)p_plistPath;
- (void)p_loadLocalRecentContacts;
- (void)p_loadTopSession:(LoadTopSessionCompletion)completion;

@end

@implementation DDRecentContactsModule
{
    BOOL _finishedLoadRecentUsers;
    BOOL _finishedLoadRecentGroups;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _finishedLoadRecentGroups = NO;
        _finishedLoadRecentUsers = NO;
    }
    return self;
}

- (void)loadRecentContacts:(LoadRecentContactsCompletion)completion
{
    [self p_loadLocalRecentContacts];
    [self p_mergerUsersAndGroups];
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil);
    });
    
    
    //获取最近联系用户
    DDSessionModule* sessionModule = getDDSessionModule();
    [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
        [self p_loadRecentUsers:^{
            [[DDSundriesCenter instance] pushTaskToSerialQueue:^{

                _finishedLoadRecentUsers = YES;
                if (_finishedLoadRecentGroups && _finishedLoadRecentUsers)
                {
                    [self p_loadTopSession:^{
                        [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                            [self p_mergerUsersAndGroups];
                            [self saveRecentContacts];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                log4Info(@"获取最近联系人成功");
                                completion(sessionModule.recentlySessionIds);
                            });

                        }];
                    }];
                }
            }];
        }];
        
        [self p_loadRecentGroups:^{
            [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                _finishedLoadRecentGroups = YES;
                if (_finishedLoadRecentUsers && _finishedLoadRecentGroups)
                {
                    [self p_loadTopSession:^{
                        [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                            [self p_mergerUsersAndGroups];
                            [self saveRecentContacts];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                log4Info(@"获取最近联系人成功");
                                completion(sessionModule.recentlySessionIds);
                            });
                        }];
                    }];
                }
            }];

        }];
        
    }];
}

- (void)saveRecentContacts
{
    NSMutableArray* recentContacts = [[NSMutableArray alloc] init];
    DDGroupModule* groupModule = getDDGroupModule();
    DDUserlistModule* userModule = getDDUserlistModule();
    
    for(NSString* groupID in groupModule.recentlyGroupIds)
    {
        GroupEntity* group = [groupModule getGroupByGId:groupID];
        NSDictionary* groupDic = @{@"ID":group.groupId,
                                   @"name":group.name,
                                   @"grouMembers":group.groupUserIds,
                                   @"type":@(group.groupType),
                                   @"lastTime":@(group.groupUpdated),
                                   @"creatorId":group.groupCreatorId,
                                   @"EntityType":@(1)};
        [recentContacts addObject:groupDic];
    }
    
    for(NSString* uId in userModule.recentlyUserIds)
    {
        UserEntity* user = [userModule getUserById:uId];
        NSDictionary* userDic = @{@"ID":user.userId,
                                  @"name":user.name,
                                  @"avatar":user.avatar,
                                  @"lastTime":@(user.userUpdated),
                                  @"userRole":@(user.userRole),
                                  @"EntityType":@(2)};
        if ([user.name isEqualToString:@"项目发布"])
        {
            DDLog(@"asd");
        }
        [recentContacts addObject:userDic];
    }
    
    NSString* path = [self p_plistPath];
    [recentContacts writeToFile:path atomically:YES];
}

#pragma mark PrivateAPI

- (void)p_loadRecentUsers:(RecentUsersCompletion)completion
{
    DDUserlistModule* userModule = getDDUserlistModule();
    DDRecentConactsAPI* contactsApi = [[DDRecentConactsAPI alloc] init];
    [contactsApi requestWithObject:nil Completion:^(id response, NSError *error) {
        if (!error)
        {
            [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                NSArray* recentlyUsers = (NSArray*)response;
                if (!userModule.recentlyUserIds)
                {
                    userModule.recentlyUserIds = [[NSMutableArray alloc] init];
                }
                for (UserEntity *user in recentlyUsers)
                {
                    if (![userModule.recentlyUserIds containsObject:user.userId] && ![userModule isInIgnoreUserList:user.userId])
                    {
                        [userModule.recentlyUserIds addObject:user.userId];
                        [userModule addUser:user];
                    }
                    else
                    {
                        UserEntity* userEntity = [userModule getUserById:user.userId];
                        userEntity.userUpdated = user.userUpdated;
                        userEntity.avatar = [user.avatar copy];
                        userEntity.name = [user.name copy];
                        userEntity.nick = [user.nick copy];
                        userEntity.department = [user.department copy];
                    }
                }
                [self saveRecentContacts];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });

            }];
        }
        else
        {
            [self p_loadRecentUsers:completion];
            DDLog(@"error:%@",[error domain]);
        }
    }];
}

- (void)p_loadRecentGroups:(RecentGroupCompletion)completion
{
    DDGroupModule* groupModule = getDDGroupModule();
    DDRecentGroupAPI* groupApi = [[DDRecentGroupAPI alloc] init];
    [groupApi requestWithObject:nil Completion:^(id response, NSError *error) {
        if (!error)
        {
            [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                NSArray* recentlyGroups = (NSArray*)response;
                if (!groupModule.recentlyGroupIds) {
                    groupModule.recentlyGroupIds = [[NSMutableArray alloc] init];
                }
                for(GroupEntity* group in recentlyGroups)
                {
//                    if ([group.name isEqualToString:@"MIT"])
//                    {
//                    static int index = 0;
//                    index ++;
//                        DDLog(@"----------->%@  %i",group.name,index);
//                    }
                    if (![groupModule.recentlyGroupIds containsObject:group.groupId]) {
                        [groupModule addGroup:group];
                        [[SpellLibrary instance] addSpellForObject:group];
                        [groupModule.recentlyGroupIds addObject:group.groupId];
                    }
                    else
                    {
                        GroupEntity* oldGroup = [groupModule getGroupByGId:group.groupId];
                        oldGroup.groupUserIds = [group.groupUserIds mutableCopy];
                        oldGroup.name = [group.name copy];
                        oldGroup.groupUpdated = group.groupUpdated;
                    }
                }
                [self saveRecentContacts];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }];
        }
        else
        {
            [self p_loadRecentGroups:completion];
            DDLog(@"error:%@",[error domain]);
        }
    }];
}

- (void)p_mergerUsersAndGroups
{
    DDSessionModule* sessionModule = getDDSessionModule();
    DDGroupModule* groupModule = getDDGroupModule();
    DDUserlistModule* userModule = getDDUserlistModule();
    
    NSArray* arrUserIds = userModule.recentlyUserIds;
    for(NSString* groupID in groupModule.recentlyGroupIds)
    {
        GroupEntity* group = [groupModule getGroupByGId:groupID];
        SessionEntity* session = [[SessionEntity alloc] init];
        session.sessionId = group.groupId;
        session.lastSessionTime = group.groupUpdated;
        if (group.groupType == 1)
        {
            session.type = SESSIONTYPE_GROUP;
        }
        else if (group.groupType == 2)
        {
            session.type = SESSIONTYPE_TEMP_GROUP;
        }
        if (![sessionModule.recentlySessionIds containsObject:session.sessionId])
        {
            [sessionModule addSession:session];
            [sessionModule.recentlySessionIds addObject:session.sessionId];
        }
    }
    
    for(NSString* uId in arrUserIds)
    {
        SessionEntity* session = [[SessionEntity alloc] init];
        session.sessionId = uId;
        session.type = SESSIONTYPE_SINGLE;
        UserEntity* user = [userModule getUserById:uId];
        session.lastSessionTime = user.userUpdated;
        if (![sessionModule.recentlySessionIds containsObject:session.sessionId])
        {
            [sessionModule addSession:session];
            [sessionModule.recentlySessionIds addObject:session.sessionId];
        }
    }
}

- (void)p_loadLocalRecentContacts
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    NSString *plistPath = [self p_plistPath];
    
    if([fileManager fileExistsAtPath:plistPath])
    {
        NSArray* array = [[NSArray alloc] initWithContentsOfFile:plistPath];
        DDUserlistModule* userModule = getDDUserlistModule();
        DDGroupModule* groupModule = getDDGroupModule();
        [[DDSundriesCenter instance] pushTaskToSynchronizationSerialQUeue:^{

            [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSDictionary* dic = (NSDictionary*)obj;
                int type = [dic[@"EntityType"] intValue];
                if (type == 2)
                {
                    UserEntity* user = [[UserEntity alloc] init];
                    user.userId = dic[@"ID"];
                    user.name = dic[@"name"];
                    user.userUpdated = [dic[@"lastTime"] intValue];
                    user.userRole = [dic[@"userRole"] intValue];
                    user.avatar = dic[@"avatar"];
                    if ([userModule isInIgnoreUserList:user.userId])
                    {
                        return;
                    }
                    if (!userModule.recentlyUserIds)
                    {
                        userModule.recentlyUserIds = [[NSMutableArray alloc] init];
                    }
                    [userModule.recentlyUserIds addObject:user.userId];
                    [userModule addUser:user];
                }
                else
                {
                    GroupEntity* group = [[GroupEntity alloc] init];
                    group.groupId = dic[@"ID"];
                    group.name = dic[@"name"];
                    group.groupUserIds = dic[@"grouMembers"];
                    group.groupType = [dic[@"type"] intValue];
                    group.groupUpdated = [dic[@"lastTime"] intValue];
                    group.groupCreatorId = dic[@"creatorId"];
                    
                    if (!groupModule.recentlyGroupIds)
                    {
                        groupModule.recentlyGroupIds = [[NSMutableArray alloc] init];
                    }
                    [groupModule addGroup:group];
                    [[SpellLibrary instance] addSpellForObject:group];
                    [groupModule.recentlyGroupIds addObject:group.groupId];
                }
            }];
        }];

    }
}


- (NSString*)p_plistPath
{
    DDUserlistModule* userListModule = getDDUserlistModule();
    NSString* myName = [[userListModule myUser] userId];
    
    NSString* directorPath = [[DDPathHelp applicationSupportDirectory] stringByAppendingPathComponent:myName];
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    BOOL isDirector = NO;
    BOOL isExiting = [fileManager fileExistsAtPath:directorPath isDirectory:&isDirector];
    
    if (!(isExiting && isDirector))
    {
        BOOL createDirection = [fileManager createDirectoryAtPath:directorPath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        if (!createDirection)
        {
            DDLog(@"create director");
        }
    }
    
    
    NSString *plistPath = [directorPath stringByAppendingPathComponent:RECETNT_CONTACTS_PLIST_FILE];
    return plistPath;
}

- (void)p_loadTopSession:(LoadTopSessionCompletion)completion
{
    DDSessionModule* sessionModule = getDDSessionModule();
    DDGroupModule* groupModule = getDDGroupModule();
    DDUserlistModule* userModule = getDDUserlistModule();
    
    DDSetting* setting = [DDSetting instance];
    NSArray* topSession = [setting getTopSessionIDs];
    __block NSUInteger finishedCount = 0;
    NSUInteger count = [topSession count];
    if (count == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
        return;
    }
    for (NSUInteger index = 0; index < [topSession count]; index ++)
    {
        NSString* ID = topSession[index];
        if (![groupModule getGroupByGId:ID] && ![userModule getUserById:ID])
        {
            if ([ID hasPrefix:GROUP_PRE])
            {
                DDGroupInfoAPI* groupInfo = [[DDGroupInfoAPI alloc] init];
                [groupInfo requestWithObject:[ID substringFromIndex:[GROUP_PRE length]] Completion:^(id response, NSError *error)
                 {
                     finishedCount ++;
                     if (!error)
                     {
                         [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                             GroupEntity* group = (GroupEntity*)response;
                             if (![groupModule.recentlyGroupIds containsObject:group.groupId])
                             {
                                 [groupModule addGroup:group];
                                 [[SpellLibrary instance] addSpellForObject:group];
                                 [groupModule.recentlyGroupIds addObject:group.groupId];
                             }
                             if (finishedCount == count)
                             {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     completion();
                                 });
                             }
                         }];
                         
                     }
                 }];
            }
            else
            {
                DDUserInfoAPI* userInfo = [[DDUserInfoAPI alloc] init];
                [userInfo requestWithObject:@[ID] Completion:^(id response, NSError *error)
                 {
                     finishedCount ++;
                     if (!error)
                     {
                         [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                             UserEntity* user = (UserEntity*)response[0];
                             if (![userModule.recentlyUserIds containsObject:user.userId])
                             {
                                 [userModule addUser:user];
                                 [userModule.recentlyUserIds addObject:user.userId];
                             }
                             if (finishedCount == count)
                             {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     completion();
                                 });
                             }
                         }];
                     }
                 }];
            }
        }
        else
        {
            finishedCount ++;
            if (finishedCount == count)
            {
                if (finishedCount == count)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion();
                    });
                }
            }
        }
    }
}
@end
