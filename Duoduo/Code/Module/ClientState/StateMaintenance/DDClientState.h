//
//  DDClientState.h
//  Duoduo
//
//  Created by 独嘉 on 14-4-14.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DDClientState : NSObject

@property (nonatomic,assign)BOOL socketLink;            //IO是否正常
@property (nonatomic,assign)BOOL networkFine;           //网络连接是否正常
@property (nonatomic,assign)BOOL kickout;               //是否被挤下来了
@property (nonatomic,assign)BOOL userInitiativeOffline;  //用户主动下线
@property (nonatomic,strong)NSString* userID;            //登录的用户ID
@property (nonatomic,assign)BOOL online;
+ (instancetype)instance;
@end
