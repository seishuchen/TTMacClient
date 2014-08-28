//
//  DDCurrentUserState.h
//  Duoduo
//
//  Created by 独嘉 on 14-4-9.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import <Foundation/Foundation.h>
@class UserEntity;
@interface DDCurrentUserState : NSObject
@property (nonatomic,readonly)UserEntity* user;
+ (instancetype)instance;

/**
 *  初始化登录用户
 *
 *  @param user 登录用户
 */
- (void)loginTheUser:(UserEntity*)user;

@end
