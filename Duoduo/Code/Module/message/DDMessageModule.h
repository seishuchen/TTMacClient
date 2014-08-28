/************************************************************
 * @file         DDMessageModule.h
 * @author       快刀<kuaidao@mogujie.com>
 * summery       消息管理模块
 ************************************************************/

#import <Foundation/Foundation.h>
#import "DDLogic.h"
#import "DDIntranetMessageEntity.h"
typedef void(^LoadAllUnReadMessageCompletion)(NSError* error);

@class MessageEntity;
@class SessionEntity;
@class DDSendMessageAckManager;
@interface DDMessageModule : DDModule
{
    NSMutableDictionary*                _allUnReadedMessages; //所有未读消息 key:session id  value:message array
    NSMutableDictionary*                _historyMsgOffset;
    DDSendMessageAckManager*            _sendMsgAckManager;
    NSMutableDictionary*                _intranetUnreadMessages;
    NSMutableDictionary*                _unSendAckMessages;
}

-(id) initModule;

/**
 *  插入到未读消息维护数据中
 *
 *  @param sessionId 会话ID
 *  @param msgEntity 未读消息
 *
 *  @return 是否维护成功
 */
-(BOOL)pushMessage:(NSString*)sessionId message:(MessageEntity*)msgEntity;

/**
 *  批量插入未读消息维护数据
 *
 *  @param msgEntities 未读消息
 *  @param sessionID   会话ID
 *
 *  @return 是否维护成功
 */
-(BOOL)pushMessages:(NSArray*)msgEntities sessionID:(NSString*)sessionID;

/**
 *  获得相应会话的未读消息中的最早的一条消息,并使这条消息从未读消息中移除
 *
 *  @param sessionId 相应的会话ID
 *
 *  @return 消息
 */
-(MessageEntity*)popMessage:(NSString*)sessionId;

/**
 *  获得相应会话的未读消息中的最早的一条消息,这条消息不从未读消息中移除
 *
 *  @param sessionId 相应的会话ID
 *
 *  @return 消息
 */
//-(MessageEntity*)frontMessage:(NSString*)sessionId;

/**
 *  获得某个会话的未读消息，同时这个函数会把这些消息写入到历史消息数据库中
 *
 *  @param sessionId 会话ID
 *
 *  @return 此会话的未读消息
 */
-(NSArray*)popArrayMessage:(NSString*)sessionId;

/**
 *  从未读消息中移除相应会话的未读消息，不插入到历史消息数据库
 *
 *  @param sessionId 会话ID
 */
-(void)removeArrayMessage:(NSString*)sessionId;

/**
 *  获得相应会话的未读消息数量
 *
 *  @param sessionId 会话ID
 *
 *  @return 未读消息数量
 */
-(NSUInteger)countMessageBySessionId:(NSString*)sessionId;

/**
 *  获得所有的未读消息数量
 *
 *  @return 未读消息数量s
 */
-(NSUInteger)countUnreadMessage;

/**
 *  判断是否有未读消息
 *
 *  @return 是否有未读消息
 */
- (BOOL)hasUnreadedMessage;

//历史消息相关
//-(void)tcpSendHistoryMsgReq:(SessionEntity*)session msgOffset:(uint32_t)msgOffset;
-(void)countHistoryMsgOffset:(NSString*)sId offset:(uint32)offset;

//消息ack相关
-(void)pushSendMsgForAck:(uint32)seqNo message:(MessageEntity*)msg;

-(void)pushSendMsgForAck:(uint32)seqNo;
-(void)ackSendMsg:(uint32) seqNo;
-(BOOL)sendSuccessForMsg:(uint32)seqNo;

-(void)fetchAllUnReadMessageCompletion:(LoadAllUnReadMessageCompletion)completion;

- (void)addUnreadMessage:(DDIntranetMessageEntity*)message inIntranetForSessionID:(NSString*)sessionID;
- (int)countOfUnreadIntranetMessageForSessionID:(NSString*)sessionID;
- (void)clearAllUnreadMessageInIntranetForSessionID:(NSString*)sessionID;
@end

extern DDMessageModule* getDDMessageModule();

