//
//  DDIntranetEntity.m
//  Duoduo
//
//  Created by 独嘉 on 14-6-25.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDIntranetEntity.h"

@implementation DDIntranetEntity
- (id)initWithAvatar:(NSString*)avatar title:(NSString*)title url:(NSString*)url fromUserID:(NSString*)fromUserID
{
    self = [super init];
    if (self)
    {
        _avatar = [avatar copy];
        _title = [title copy];
        _url = [url copy];
        _fromUserID = [fromUserID copy];
    }
    return self;
}
@end
