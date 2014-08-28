//
//  DDIntranetEntity.h
//  Duoduo
//
//  Created by 独嘉 on 14-6-25.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DDIntranetEntity : NSObject
@property (nonatomic,readonly)NSString* avatar;
@property (nonatomic,readonly)NSString* title;
@property (nonatomic,readonly)NSString* url;
@property (nonatomic,readonly)NSString* fromUserID;
- (id)initWithAvatar:(NSString*)avatar title:(NSString*)title url:(NSString*)url fromUserID:(NSString*)fromUserID;
@end
