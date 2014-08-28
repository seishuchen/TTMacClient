//
//  DDRecentContactsViewController.m
//  Duoduo
//
//  Created by 独嘉 on 14-4-29.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDRecentContactsViewController.h"
#import "DDSessionModule.h"
#import "DDRecentContactsCell.h"
#import "DDMessageModule.h"
#import "DDSearch.h"
#import "DDSearchViewController.h"
#import "DDHttpModule.h"
#import "UserEntity.h"
#import "DDUserlistModule.h"
#import "DDAlertWindowController.h"
#import "GroupEntity.h"
#import "DDRecentContactsModule.h"
#import "SessionEntity.h"
#import "DDSetting.h"
#import "DDUserInfoManager.h"
#import "DDRemoveSessionAPI.h"
#import "DDGroupModule.h"
#import "DDGroupInfoManager.h"
#import "NSView+LayerAddition.h"
@interface DDRecentContactsViewController ()

- (void)p_clickTheTableView;
- (void)p_showSearchResultView;
- (void)p_searchOnline:(NSString*)content;

- (void)n_receiveReloadRecentContacts:(NSNotification*)notification;
- (void)n_receiveStateChanged:(NSNotification*)notification;

- (void)p_resetSelectedRow;

- (void)p_receiveBoundsChanged:(NSNotification*)notification;
@end

@implementation DDRecentContactsViewController
{
    NSString* _selectedSessionID;
}
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        _selectedSessionID = @"";
    }
    return self;
}

- (void)awakeFromNib
{
    [_tableView setHeaderView:nil];
    [_tableView setTarget:self];
    [_tableView setAction:@selector(p_clickTheTableView)];
    
    [_tableView setMenu:self.menu];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_receiveBoundsChanged:) name:NSViewBoundsDidChangeNotification object:nil];
    self.popover = [[NSPopover alloc] init];
    self.popover.contentViewController = _searchViewController;
    self.popover.behavior = NSPopoverBehaviorTransient;
//    [_searchViewController.view removeFromSuperview];
//    [self.view addSubview:_searchViewController.view positioned:NSWindowAbove relativeTo:nil];
//    [_searchViewController.view setHidden:YES];
    
}

- (DDRecentContactsModule*)module
{
    if (!_module)
    {
        _module = [[DDRecentContactsModule alloc] init];
    }
    return _module;
}

#pragma mark public API
- (void)selectSession:(NSString*)sessionID
{
    DDSessionModule* moduleSess = getDDSessionModule();
    NSArray* recentSessionIDs = moduleSess.recentlySessionIds;
    NSInteger selectedRow = [recentSessionIDs indexOfObject:sessionID];
    if([recentSessionIDs containsObject:sessionID])
    {
        if (selectedRow >= 0)
        {
            NSString* sId = moduleSess.recentlySessionIds[selectedRow];
            _selectedSessionID = sId;
            [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            _selectedSessionID = sessionID;
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
            [_tableView scrollRowToVisible:selectedRow];
        }
    }
}

- (void)updateData
{
    [_tableView reloadData];
}

- (void)initialData
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveReloadRecentContacts:) name:notificationReloadTheRecentContacts object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveStateChanged:) name:notificationonlineStateChange object:nil];
    [self.module loadRecentContacts:^(NSArray *contacts) {
        DDSessionModule* sessionModule = getDDSessionModule();
        [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
            [sessionModule sortRecentlySessions];
            dispatch_async(dispatch_get_main_queue(), ^{
                [_tableView reloadData];
            });
        }];
    }];
}

#pragma mark - Menu Action
- (IBAction)removeSession:(id)sender
{
    NSInteger rowNumber = [_tableView clickedRow];
    NSUInteger selectedRowNumber = [_tableView selectedRow];
    if (rowNumber < 0)
    {
        return;
    }
    DDSessionModule* moduleSess = getDDSessionModule();
    NSString* sId = moduleSess.recentlySessionIds[rowNumber];
    SessionEntity* session = [moduleSess getSessionBySId:sId];
    
    //发送移除会话请求
    uint32_t sessionType = 0;
    switch (session.type)
    {
        case SESSIONTYPE_SINGLE:
            sessionType = 1;
            break;
        case SESSIONTYPE_GROUP:
        case SESSIONTYPE_TEMP_GROUP:
            sessionType = 2;
            break;
    }
    
    DDRemoveSessionAPI* removeSessionAPI = [[DDRemoveSessionAPI alloc] init];
    NSArray* object = @[session.orginId,@(sessionType)];
    [removeSessionAPI requestWithObject:object Completion:^(id response, NSError *error) {
        if (!error) {
            if (!response)
            {
                return;
            }
            [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
                DDSessionModule* sessionModule = getDDSessionModule();
                NSInteger row = [sessionModule.recentlySessionIds indexOfObject:sId];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [_tableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationSlideDown];
                    if (selectedRowNumber == row)
                    {
                        [self selectSession:sessionModule.recentlySessionIds[0]];
                        [self.delegate recentContactsViewController:self selectSession:sessionModule.recentlySessionIds[0]];
                    }
                });
                
                if ([session.sessionId hasPrefix:GROUP_PRE])
                {
                    DDGroupModule* groupModule = getDDGroupModule();
                    [groupModule.recentlyGroupIds removeObject:session.sessionId];
                }
                else
                {
                    DDUserlistModule* userModule = getDDUserlistModule();
                    [userModule.recentlyUserIds removeObject:session.sessionId];
                }
                [sessionModule.recentlySessionIds removeObject:session.sessionId];
                DDMessageModule* messageModule = getDDMessageModule();
                [messageModule popArrayMessage:session.sessionId];
                [self.module saveRecentContacts];
                [NotificationHelp postNotification:notificationReloadTheRecentContacts userInfo:nil object:nil];
//                [sessionModule sortRecentlySessions];
            }];
        }
        else
        {
            DDLog(@"Error:%@",[error domain]);
        }
    }];
}

- (IBAction)viewContact:(id)sender
{
    NSInteger rowNumber = [_tableView clickedRow];
    if(rowNumber < 0)
        return;
    
    
    DDSessionModule* moduleSess = getDDSessionModule();
    NSString* sId = moduleSess.recentlySessionIds[rowNumber];
    
    if (![sId hasPrefix:@"group"])
    {
        DDUserlistModule* userListModel = getDDUserlistModule();
        UserEntity* showUser = [userListModel getUserById:sId];
        
        [[DDUserInfoManager instance] showUser:showUser forContext:self];
    }
    else
    {
        DDGroupModule* groupModule = getDDGroupModule();
        GroupEntity* group = [groupModule getGroupByGId:sId];
        
        [[DDGroupInfoManager instance] showGroup:group context:self];
    }
    
}

-(IBAction)topSession:(id)sender
{
    NSInteger clickRow = [_tableView clickedRow];
    if(clickRow < 0)
        return;
    
    DDSessionModule* moduleSess = getDDSessionModule();
    NSString* sId = moduleSess.recentlySessionIds[clickRow];
    
    [[DDSetting instance] addTopSessionID:sId];
    DDSessionModule* sessionModule = getDDSessionModule();
    [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
        [sessionModule sortRecentlySessions];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger row = [sessionModule.recentlySessionIds indexOfObject:sId];
            [_tableView moveRowAtIndex:clickRow toIndex:row];
            [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];

        });
    }];
}

-(IBAction)cancelTopSession:(id)sender
{
    NSInteger rowNumber = [_tableView clickedRow];
    if(rowNumber < 0)
        return;
    
    DDSessionModule* moduleSess = getDDSessionModule();
    NSString* sId = moduleSess.recentlySessionIds[rowNumber];
    
    [[DDSetting instance] removeTopSessionID:sId];
    DDSessionModule* sessionModule = getDDSessionModule();
    [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
        [sessionModule sortRecentlySessions];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger row = [sessionModule.recentlySessionIds indexOfObject:sId];
            [_tableView moveRowAtIndex:rowNumber toIndex:row];
            [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        });
    }];
}

-(IBAction)shieldSession:(id)sender
{
    NSInteger rowNumber = [_tableView clickedRow];
    if(rowNumber < 0)
        return;
    
    DDSessionModule* moduleSess = getDDSessionModule();
    NSString* sId = moduleSess.recentlySessionIds[rowNumber];
    
    [[DDSetting instance] addShieldSessionID:sId];
    
    [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:rowNumber] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    
}

-(IBAction)cancelShieldSession:(id)sender
{
    NSInteger rowNumber = [_tableView clickedRow];
    if(rowNumber < 0)
        return;
    
    DDSessionModule* moduleSess = getDDSessionModule();
    NSString* sId = moduleSess.recentlySessionIds[rowNumber];
    
    [[DDSetting instance] removeShieldSessionID:sId];
    [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:rowNumber] columnIndexes:[NSIndexSet indexSetWithIndex:0]];

}

#pragma mark - DDSearchViewControllerDelegate
- (void)selectTheSearchResultObject:(id)object
{
    NSString* sessionID = nil;
    int type = 0;
    if ([object isKindOfClass:[UserEntity class]])
    {
        sessionID = [(UserEntity*)object userId];
    }
    else
    {
        sessionID = [(GroupEntity*)object groupId];
        type = [(GroupEntity*)object groupType];
    }
    //[_searchViewController.view setHidden:YES];
    [self hiddenPopView];
    [_searchField setStringValue:@""];
    DDSessionModule* sessionModule = getDDSessionModule();
    if (![sessionModule.recentlySessionIds containsObject:sessionID])
    {
        if ([sessionID hasPrefix:@"group"])
        {
            [sessionModule createGroupSession:sessionID type:type];
        }
        else
        {
            [sessionModule createSingleSession:sessionID];
        }
        [self n_receiveReloadRecentContacts:nil];
    }
    [self selectSession:sessionID];
    [[DDMainWindowController instance] openChat:sessionID icon:nil];
}

#pragma mark - NSMenu Delegate
- (void)menuWillOpen:(NSMenu *)menu
{
    NSInteger rowNumber = [_tableView clickedRow];
    if(rowNumber < 0)
        return;
    
    //设置移除会话菜单
    DDSessionModule* sessionModule = getDDSessionModule();
    NSString* sessionID = sessionModule.recentlySessionIds[rowNumber];
    SessionEntity* session = [sessionModule getSessionBySId:sessionID];
    BOOL removeItemShow = YES;
    if (session.type == SESSIONTYPE_SINGLE)
    {
        UserEntity* user = [getDDUserlistModule() getUserById:session.orginId];
        if((user.userRole & 0x20000000) != 0)
        {
            //公共帐号
            removeItemShow = NO;
        }
    }
    NSArray* topSession = [[DDSetting instance] getTopSessionIDs];
    if ([topSession containsObject:sessionID])
    {
        removeItemShow = NO;
    }
    
    NSMenuItem* removeMenuItem = [menu itemAtIndex:0];
    [removeMenuItem setHidden:!removeItemShow];
    
    
    //设置置顶菜单
    if ([topSession containsObject:sessionID])
    {
        NSMenuItem* topMenuItem = [menu itemAtIndex:2];
        [topMenuItem setHidden:YES];
        
        NSMenuItem* cancelMenuItem = [menu itemAtIndex:3];
        [cancelMenuItem setHidden:NO];
        
    }
    else
    {
        NSMenuItem* topMenuItem = [menu itemAtIndex:2];
        [topMenuItem setHidden:NO];
        
        
        NSMenuItem* cancelMenuItem = [menu itemAtIndex:3];
        [cancelMenuItem setHidden:YES];
        
    }
    //设置屏蔽菜单
    if (session.type == SESSIONTYPE_SINGLE)
    {
        NSMenuItem* shieldMenuItem = [menu itemAtIndex:5];
        [shieldMenuItem setHidden:YES];
        
        NSMenuItem* cancelShieldMenuItem = [menu itemAtIndex:6];
        [cancelShieldMenuItem setHidden:YES];
    }
    NSArray* shieldSessions = [[DDSetting instance] getShieldSessionIDs];
    if ([shieldSessions containsObject:sessionID])
    {
        NSMenuItem* shieldMenuItem = [menu itemAtIndex:5];
        [shieldMenuItem setHidden:YES];
        
        NSMenuItem* cancelShieldMenuItem = [menu itemAtIndex:6];
        [cancelShieldMenuItem setHidden:NO];
    }
    else
    {
        NSMenuItem* shieldMenuItem = [menu itemAtIndex:5];
        [shieldMenuItem setHidden:NO];
        
        NSMenuItem* cancelShieldMenuItem = [menu itemAtIndex:6];
        [cancelShieldMenuItem setHidden:YES];
    }
    
}

#pragma mark NSTextField Delegate

- (void)controlTextDidChange:(NSNotification *)obj
{
   
    DDSearch* search = [DDSearch instance];
    [search searchContent:_searchField.stringValue completion:^(NSArray *result, NSError *error) {
        if ([result count] == 0)
        {
            //[_searchViewController.view setHidden:YES];
            [self hiddenPopView];
        }
        else
        {
            [_searchViewController setShowData:result];
            CGFloat height = 0;
            if ([result count] > 10)
            {
                height = [_searchViewController rowHeight] * 10;
            }
            else
            {
                height = [_searchViewController rowHeight] * [result count] + 6;
            }
            [self.popover setContentSize:NSMakeSize(self.view.bounds.size.width, height)];
//            [_searchViewController.view setFrameSize:NSMakeSize(self.view.bounds.size.width, height)];
            [self p_showSearchResultView];
        }
    }];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
//    if (![control isEqual:_searchField])
//    {
//        return YES;
//    }
    if ([NSStringFromSelector(commandSelector) isEqualToString:@"moveDown:"])
    {
        [_searchViewController selectNext];
    }
    else if ([NSStringFromSelector(commandSelector) isEqualToString:@"moveUp:"])
    {
        [_searchViewController selectLast];
    }
    else if ([NSStringFromSelector(commandSelector) isEqualToString:@"insertNewline:"])
    {
        BOOL searchHidden = [_searchViewController.view isHidden];
        if (searchHidden)
        {
            [self p_searchOnline:textView.string];
        }
        else
        {
            id object = [_searchViewController selectedObject];
            NSString* sessionID = nil;
            int type = 0;
            if ([object isKindOfClass:[UserEntity class]])
            {
                sessionID = [(UserEntity*)object userId];
            }
            else
            {
                sessionID = [(GroupEntity*)object groupId];
                type = [(GroupEntity*)object groupType];
            }
            //[_searchViewController.view setHidden:YES];
            [self hiddenPopView];
            [_searchField setStringValue:@""];
            DDSessionModule* sessionModule = getDDSessionModule();
            if (![sessionModule.recentlySessionIds containsObject:sessionID])
            {
                if ([sessionID hasPrefix:@"group"])
                {
                    [sessionModule createGroupSession:sessionID type:type];
                }
                else
                {
                    [sessionModule createSingleSession:sessionID];
                }
                [self n_receiveReloadRecentContacts:nil];
            }
            [self selectSession:sessionID];
            [[DDMainWindowController instance] openChat:sessionID icon:nil];
        }
    }
	else
    {
        if ([textView respondsToSelector:commandSelector])
        {
            [textView performSelector:commandSelector withObject:nil afterDelay:0];
        }
    }
    return YES;
}

#pragma mark TableView DataSource
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    DDSessionModule* moduleSess = getDDSessionModule();
    return [moduleSess.recentlySessionIds count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 50;
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    DDSessionModule* moduleSess = getDDSessionModule();
    NSString* sId = moduleSess.recentlySessionIds[row];
    SessionEntity* session = [moduleSess getSessionBySId:sId];
    
    NSString* identifier = [tableColumn identifier];
    NSString* cellIdentifier = @"RecentContactCellIdentifier";
    if ([identifier isEqualToString:@"RecentContactColumnIdentifier"])
    {
        DDRecentContactsCell* cell = (DDRecentContactsCell*)[tableView makeViewWithIdentifier:cellIdentifier owner:self];
        [cell configeCellWithObject:session];
        
        return cell;
    }
    return nil;
}

#pragma mark privateAPI
- (void)p_clickTheTableView
{
    NSInteger selectedRow = [_tableView selectedRow];
    DDSessionModule* moduleSess = getDDSessionModule();
    if (selectedRow >= 0)
    {
        NSString* sId = moduleSess.recentlySessionIds[selectedRow];
//        UserEntity* user = [getDDUserlistModule() getUserById:sId];
        _selectedSessionID = sId;
        if (self.delegate)
        {
            [self.delegate recentContactsViewController:self selectSession:sId];
        }
        [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] columnIndexes:[NSIndexSet indexSetWithIndex:0]];

    }
}

- (void)p_showSearchResultView
{

    [_searchViewController.view setHidden:NO];
    if (self.isShowPop == 0) {
            [self.popover showRelativeToRect:[self.searchField bounds] ofView:self.searchField preferredEdge:NSMaxXEdge];
        [self.searchField becomeFirstResponder];
        [[self.searchField currentEditor] moveToEndOfLine:nil];
        self.isShowPop =1;
    }

//    CGFloat y = self.view.bounds.size.height - 49 - _searchViewController.view.bounds.size.height;
//    [_searchViewController.view setFrameOrigin:NSMakePoint(0, y)];
//    [self.view addSubview:_searchViewController.view positioned:NSWindowAbove relativeTo:nil];
}

- (void)p_searchOnline:(NSString*)content
{
    NSString *selectedUserName = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([selectedUserName length]>0) {
            //本地查无此人.
        DDHttpModule *module = getDDHttpModule();
        NSMutableDictionary* dictParams = [NSMutableDictionary dictionary];
        [dictParams setObject:selectedUserName forKey:@"uname"];
        [module httpPostWithUri:@"mtalk/user/find" params:dictParams
                        success:^(NSDictionary *result)
         {
             /*
              网络上查找用户:{
              avatar = "http://s6.mogujie.cn/b7/avatar/130927/ba68_kqywqzkwkfbgutcugfjeg5sckzsew_180x180.jpg";
              status = 2;
              uid = 1mke0;
              uname = "\U4fee\U7f57";
              userType = 1073741824;
              */
             DDUserlistModule *userListModule = getDDUserlistModule();
             NSString *userId = [result objectForKey:@"uid"];
             NSString *name = [result objectForKey:@"uname"];
             NSString *nick = [result objectForKey:@"uname"];
             NSString *avatar = [result objectForKey:@"avatar"];
             //为了区分小仙小侠帐号用.
             NSInteger userType = (NSInteger)[result objectForKey:@"userType"];
             
             UserEntity *user = [[UserEntity alloc] init];
             user.userId = userId;
             user.name = name;
             user.nick = nick;
             user.avatar = avatar;
             user.userRole = userType;
             [userListModule.recentlyUserIds addObject:user.userId];
             [userListModule addUser:user];
             
             DDSessionModule* sessionModule = getDDSessionModule();
             if (![sessionModule.recentlySessionIds containsObject:userId])
             {
                [sessionModule createSingleSession:userId];
                 [self n_receiveReloadRecentContacts:nil];
             }
             [self selectSession:userId];
             
             [[DDMainWindowController instance] openChatViewByUserId:userId];
         }
                        failure:^(StatusEntity *error)
         {
             [[DDAlertWindowController  defaultControler] showAlertWindow:nil title:@"提示" info:@"查无此人哦！" leftBtnName:@"" midBtnName:@"" rightBtnName:@"确定"];
             DDLog(@"serverUser fail,error code:%ld,msg:%@ userInfo:%@",error.code,error.msg,error.userInfo);
         }];
    }
    [self.searchField setStringValue:@""];
}

- (void)n_receiveReloadRecentContacts:(NSNotification*)notification
{
    log4Info(@"RecentContacts Reload");
    NSString* object = [notification object];
    NSDictionary* userInfo = [notification userInfo];
    DDSessionModule* sessionModule = getDDSessionModule();
    [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
        [sessionModule sortRecentlySessions];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (object)
            {
                [_tableView reloadData];
                [self selectSession:object];
                if (self.delegate)
                {
                    [self.delegate recentContactsViewController:self selectSession:object];
                }
            }
            else
            {
                [_tableView reloadData];
                [self p_resetSelectedRow];
            }
            
            NSNumber* scroll = userInfo[@"ScrollToSelected"];
            if ([scroll boolValue])
            {
                NSInteger selectedRow = [sessionModule.recentlySessionIds indexOfObject:_selectedSessionID];
                [_tableView scrollRowToVisible:selectedRow];
            }
            
        });
    }];

}

- (void)n_receiveStateChanged:(NSNotification *)notification
{
    [[DDSundriesCenter instance] pushTaskToSerialQueue:^{
        NSMutableIndexSet* changedIndexSet = [NSMutableIndexSet indexSet];
        NSDictionary* changeDic = [notification object];
        DDSessionModule* sessionModule = getDDSessionModule();
        [[changeDic allKeys] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([sessionModule.recentlySessionIds containsObject:obj])
            {
                @autoreleasepool {
                    NSInteger row = [sessionModule.recentlySessionIds indexOfObject:obj];
                    [changedIndexSet addIndex:row];
                }
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView reloadDataForRowIndexes:changedIndexSet columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        });
    }];
}

- (void)p_resetSelectedRow
{
    DDSessionModule* sessionModule = getDDSessionModule();
    NSArray* recentSessionIDs = sessionModule.recentlySessionIds;
    [recentSessionIDs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isEqualToString:_selectedSessionID])
        {
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
            *stop = YES;
        }
    }];
}

- (void)p_receiveBoundsChanged:(NSNotification*)notification
{
    
    id object = [notification object];
    if ([object isEqual:self.clipView])
    {
        [self hiddenPopView];
    }
}
-(void)hiddenPopView
{
    [_searchViewController.view setHidden:YES];
    [self.popover performClose:nil];
    self.isShowPop=0;
}
@end
