//
//  DDIntranetViewController.m
//  Duoduo
//
//  Created by 独嘉 on 14-6-25.
//  Copyright (c) 2014年 zuoye. All rights reserved.
//

#import "DDIntranetViewController.h"
#import "DDIntranetModule.h"
#import "DDIntranetCell.h"
#import "DDMessageModule.h"
@interface DDIntranetViewController(privateAPI)

- (void)p_clickTheTableView;
- (void)n_receiveP2PIntranetMessage:(NSNotification*)notification;

@end

@implementation DDIntranetViewController

- (DDIntranetModule*)module
{
    if (!_module)
    {
        _module = [[DDIntranetModule alloc] init];
    }
    return _module;
}

- (void)awakeFromNib
{
    [_tableView setHeaderView:nil];
    [_tableView setTarget:self];
    [_tableView setAction:@selector(p_clickTheTableView)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(n_receiveP2PIntranetMessage:) name:notificationReceiveP2PIntranetMessage object:nil];
    
}

- (void)selectItemAtIndex:(NSUInteger)index
{
    DDMessageModule* messageModule = [DDMessageModule shareInstance];
    DDIntranetEntity* intranetEntity = self.module.intranets[0];
    [messageModule clearAllUnreadMessageInIntranetForSessionID:intranetEntity.fromUserID];
    [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:0] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    [_tableView scrollRowToVisible:0];
    [self.delegate intranetViewController:self selectIntranetEntity:intranetEntity];
}

#pragma mark DataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.module.intranets count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return 50;
}

- (NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString* identifier = [tableColumn identifier];
    NSString* cellIdentifier = @"IntranentCellIdentifier";
    if ([identifier isEqualToString:@"IntranentColumnIdentifier"])
    {
        DDIntranetCell* cell = (DDIntranetCell*)[tableView makeViewWithIdentifier:cellIdentifier owner:self];
        DDIntranetEntity* intranet = self.module.intranets[row];
        [cell configWithIntranet:intranet];
        return cell;
    }
    return nil;
}

#pragma mark -
#pragma mark PrivateAPI
- (void)p_clickTheTableView
{
    NSInteger clickRow = [_tableView selectedRow];
    if (clickRow >= 0)
    {
        DDIntranetEntity* intranet = self.module.intranets[clickRow];
        if (self.delegate)
        {
            DDMessageModule* messageModule = [DDMessageModule shareInstance];
            [messageModule clearAllUnreadMessageInIntranetForSessionID:intranet.fromUserID];
            [_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:0] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

            [self.delegate intranetViewController:self selectIntranetEntity:intranet];
        }
    }
}

- (void)n_receiveP2PIntranetMessage:(NSNotification*)notification
{
    [_tableView reloadData];
}

@end
