//
//  DDIntranetModule.m
//  Duoduo
//
//  Created by 独嘉 on 14-6-25.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDIntranetModule.h"
#import "NSString+DDStringAdditions.h"
#import "MD5.h"
#import "UserEntity.h"
#import "DDUserlistModule.h"
@interface DDIntranetModule(PrivateAPI)

- (void)loadIntranets;

@end
@implementation DDIntranetModule
- (id)init
{
    self = [super init];
    if (self)
    {
        [self loadIntranets];
    }
    return self;
}

#pragma mark private API
- (void)loadIntranets
{
    //http://www.mogujie.org/ttlogin?uname=十方&from=im&token=91832d497c5f4cb1c8ee04a728c9362e
    DDUserlistModule* userListModule = [DDUserlistModule shareInstance];
    UserEntity* currentUser = [userListModule myUser];
    NSString* userName = currentUser.name;
    
    NSString* token = [[NSString stringWithFormat:@"im%@%@",userName,@"dKGMQ6wPyLUzqwiEj8TfmoguJ!E"] md5];
    
    NSString* urlString = [NSString stringWithFormat:@"http://www.mogujie.org/ttlogin?uname=%@&from=im&token=%@",[userName stringByAddingPercentEscapesForAllCharacters],token];
//    NSString* urlString = [NSString stringWithFormat:@"http://www.mogujie.org/ttlogin?uname=%@&from=im&token=55d4abb4de3a20a8f795147feec9b957",[userName stringByAddingPercentEscapesForAllCharacters]];
    
    NSString* imageName = @"intranet_icon";
    DDIntranetEntity* intranetEntity = [[DDIntranetEntity alloc]initWithAvatar:imageName title:@"内网" url:urlString fromUserID:@"1szei2"];
    _intranets = @[intranetEntity];
}
@end
