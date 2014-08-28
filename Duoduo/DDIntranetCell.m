//
//  DDIntranetCell.m
//  Duoduo
//
//  Created by 独嘉 on 14-6-25.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDIntranetCell.h"
#import "DDIntranetEntity.h"
#import "DDMessageModule.h"
@implementation DDIntranetCell

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)configWithIntranet:(DDIntranetEntity*)intranet
{
    NSURL* url = [NSURL URLWithString:intranet.avatar];
    NSImage* iconImage = [NSImage imageNamed:@"intranet_icon"];
    [avatarImageView setImage:iconImage];
    [nameTextField setStringValue:intranet.title];
    
    NSString* fromUserID = intranet.fromUserID;
    DDMessageModule* messageModule = [DDMessageModule shareInstance];
    
    int unreadMessagecount = [messageModule countOfUnreadIntranetMessageForSessionID:fromUserID];
    if (unreadMessagecount > 0)
    {
        [unreadMessageBackgroundImageView setHidden:NO];
        [unreadMessageLabel setHidden:NO];
        NSString* unreadMessageCountString = [NSString stringWithFormat:@"%i",unreadMessagecount];
        [unreadMessageLabel setStringValue:unreadMessageCountString];
    }
    else
    {
        [unreadMessageLabel setHidden:YES];
        [unreadMessageBackgroundImageView setHidden:YES];
    }
}

@end
