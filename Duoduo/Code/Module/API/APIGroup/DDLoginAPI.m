//
//  DDLoginAPI.m
//  Duoduo
//
//  Created by 独嘉 on 14-5-6.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDLoginAPI.h"
#import "UserEntity.h"
#import "LoginEntity.h"
@implementation DDLoginAPI
/**
 *  请求超时时间
 *
 *  @return 超时时间
 */
- (int)requestTimeOutTimeInterval
{
    return 5;
}

/**
 *  请求的serviceID
 *
 *  @return 对应的serviceID
 */
- (int)requestServiceID
{
    return 2;
}

/**
 *  请求返回的serviceID
 *
 *  @return 对应的serviceID
 */
- (int)responseServiceID
{
    return 2;
}

/**
 *  请求的commendID
 *
 *  @return 对应的commendID
 */
- (int)requestCommendID
{
    return CMD_LOGIN_REQ_USERLOGIN;
}

/**
 *  请求返回的commendID
 *
 *  @return 对应的commendID
 */
- (int)responseCommendID
{
    return CMD_LOGIN_RES_USERLOGIN;
}

/**
 *  解析数据的block
 *
 *  @return 解析数据的block
 */
- (Analysis)analysisReturnData
{
    Analysis analysis = (id)^(NSData* data)
    {
        DataInputStream* bodyData = [DataInputStream dataInputStreamWithData:data];
        NSInteger serverTime = [bodyData readInt];
        NSInteger loginResult = [bodyData readInt];
        DDLog(@"  >>登录消息服务器返回,服务器时间:%ld 结果:%ld",serverTime,loginResult);
        LoginEntity* logEntity = [[LoginEntity alloc] init];
        logEntity.serverTime = (uint32)serverTime;
        logEntity.result = (uint32)loginResult;
        /*
         enum {
         REFUSE_REASON_NONE				= 0,
         REFUSE_REASON_NO_MSG_SERVER		= 1,
         REFUSE_REASON_MSG_SERVER_FULL 	= 2,
         REFUSE_REASON_NO_DB_SERVER		= 3,
         REFUSE_REASON_NO_LOGIN_SERVER	= 4,
         REFUSE_REASON_NO_ROUTE_SERVER	= 5,
         REFUSE_REASON_DB_VALIDATE_FAILED = 6,
         RESUSE_REASON_VERSION_TOO_OLD	= 7,
         }
         */
        if (loginResult==0)
        {
            uint32 state = [bodyData readInt];
            NSString *userName = [bodyData readUTF];
            NSString *nickName = [bodyData readUTF];
            NSString *avatar = [bodyData readUTF];
            uint32 userType = [bodyData readInt];
            UserEntity *user = [[UserEntity alloc] init];
            user.name = userName;
            user.nick = nickName;
            user.avatar = avatar;
            user.userRole = userType;
            logEntity.myUserInfo = user;
            
            log4CInfo(@"login msg server success userID:%@ userName:%@",user.userId,user.name);
        }
        return logEntity;
    };
    return analysis;
}

/**
 *  打包数据的block
 *
 *  @return 打包数据的block
 */
- (Package)packageRequestObject
{
    Package package = (id)^(id object,uint32_t seqNo)
    {
        DataOutputStream *dataout = [[DataOutputStream alloc] init];
        
        NSArray* array = (NSArray*)object;
        
        NSString* userID = array[0];
        NSString* token = array[1];
        NSString* clientVersion = array[2];
        NSInteger status = [array[3] integerValue];
        
        uint32_t totalLen = IM_PDU_HEADER_LEN + strLen(userID) + strLen(token)
        + strLen(clientVersion) + 4 * 4;
        
        [dataout writeInt:totalLen];
        [dataout writeTcpProtocolHeader:MODULE_ID_LOGIN
                                    cId:CMD_LOGIN_REQ_USERLOGIN
                                  seqNo:seqNo];
        [dataout writeUTF:userID];
        [dataout writeUTF:token];
        [dataout writeInt:(uint32_t)status];
        [dataout writeUTF:clientVersion];
        log4CInfo(@"user login serviceID:%i cmdID:%i -->userID:%@  token:%@  status:%i clientVersion:%@",MODULE_ID_LOGIN,CMD_LOGIN_REQ_USERLOGIN,userID,token,status,clientVersion);
        return [dataout toByteArray];
    };
    return package;
}
@end
