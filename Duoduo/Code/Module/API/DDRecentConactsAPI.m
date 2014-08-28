//
//  DDRecentConactsAPI.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-24.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDRecentConactsAPI.h"
#import "UserEntity.h"
@implementation DDRecentConactsAPI

#pragma mark - DDAPIScheduleProtocol

- (int)requestTimeOutTimeInterval
{
    return 5;
}

- (int)requestServiceID
{
    return MODULE_ID_FRIENDLIST;
}

- (int)responseServiceID
{
    return MODULE_ID_FRIENDLIST;
}

- (int)requestCommendID
{
    return CMD_FRI_REQ_RECENT_LIST;
}

- (int)responseCommendID
{
    return CMD_FRI_RECENT_CONTACTS;
}

- (Analysis)analysisReturnData
{
    Analysis analysis = (id)^(NSData* data)
    {
        DataInputStream* dataInputStream = [DataInputStream dataInputStreamWithData:data];
        NSInteger userCnt = [dataInputStream readInt];
        //  NSInteger userCnt = 29;
        DDLog(@"    **** 返回最近联系人列表,有%ld个最近联系人.",userCnt);
        log4CInfo(@"get recent contacts count:%i",userCnt);
        NSMutableArray* recentlyContactContent = [[NSMutableArray alloc] init];
        for (int i=0; i<userCnt; i++) {
            NSString *userId = [dataInputStream readUTF];
            NSString *name = [dataInputStream readUTF];
            NSString *nick = [dataInputStream readUTF];
            NSString *avatar = [dataInputStream readUTF];
            //为了区分小仙小侠帐号用.
            NSInteger userType = [dataInputStream readInt];
            NSInteger userUpdated = [dataInputStream readInt];
            
            UserEntity *user = [[UserEntity alloc] init];
            user.userId = userId;
            user.name = name;
            user.nick = nick;
            user.avatar = avatar;
            user.userRole = userType;
            user.userUpdated = userUpdated;
            
            [recentlyContactContent addObject:user];
        }
        
        return recentlyContactContent;
    };
    return analysis;
}

- (Package)packageRequestObject
{
    Package package = (id)^(id object,uint32_t seqNo)
    {
        DataOutputStream *dataout = [[DataOutputStream alloc] init];
        uint32_t totalLen = 20;
        [dataout writeInt:totalLen];
        [dataout writeTcpProtocolHeader:MODULE_ID_FRIENDLIST cId:CMD_FRI_REQ_RECENT_LIST seqNo:seqNo];
        [dataout writeInt:0];
        log4CInfo(@"get recently users list serviceID:%i cmdID:%i",MODULE_ID_FRIENDLIST,CMD_FRI_REQ_RECENT_LIST);
        return [dataout toByteArray];
    };
    return package;
}
@end
