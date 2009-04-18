//
//  FriendsTimelineDataSource.m
//  TwitterFon
//
//  Created by kaz on 12/14/08.
//  Copyright 2008 naan studio. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FriendsTimelineDataSource.h"
#import "GogoTwitterAppDelegate.h"
#import "TweetViewController.h"
#import "ProfileViewController.h"

#import "TimelineCell.h"
#import "DBConnection.h"

static UIAlertView* sAlert = nil;

@interface NSObject (TimelineViewControllerDelegate)
- (void)timelineDidUpdate:(FriendsTimelineDataSource*)sender count:(int)count insertAt:(int)position;
- (void)timelineDidFailToUpdate:(FriendsTimelineDataSource*)sender position:(int)position;
@end

@implementation FriendsTimelineDataSource

@synthesize timeline;
@synthesize contentOffset;


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    int count = [timeline countStatuses];
    return (isRestored) ? count : count + 1;
}

//
// UITableViewDelegate
//
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Status* sts = [timeline statusAtIndex:indexPath.row];
    return sts ? sts.cellHeight : 78;
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    TimelineCell* cell = [timeline getTimelineCell:tableView atIndex:indexPath.row];
    if (cell) {
        return cell;
    }
    else {
        return loadCell;
    }
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    Status* sts = [timeline statusAtIndex:indexPath.row];
    
    if (sts) {
        // Display user view
        //
        if (tweetType == TWEET_TYPE_MESSAGES || tweetType == TWEET_TYPE_SENT) {
            ProfileViewController *profile = [[[ProfileViewController alloc] initWithProfile:sts.user] autorelease];
            [[controller navigationController] pushViewController:profile animated:true];
        }
        else {
            TweetViewController* tweetView = [[[TweetViewController alloc] initWithMessage:sts] autorelease];
            [[controller navigationController] pushViewController:tweetView animated:TRUE];
        }
    }      
    else {
        // Restore tweets from DB
        //
        int count = [timeline restore:tweetType all:true];
        isRestored = true;
        
        NSMutableArray *newPath = [[[NSMutableArray alloc] init] autorelease];
        
        [tableView beginUpdates];
        // Avoid to create too many table cell.
        if (count > 0) {
            if (count > 2) count = 2;
            for (int i = 0; i < count; ++i) {
                [newPath addObject:[NSIndexPath indexPathForRow:i + indexPath.row inSection:0]];
            }        
            [tableView insertRowsAtIndexPaths:newPath withRowAnimation:UITableViewRowAnimationTop];
        }
        else {
            [newPath addObject:indexPath];
            [tableView deleteRowsAtIndexPaths:newPath withRowAnimation:UITableViewRowAnimationLeft];
        }
        [tableView endUpdates];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:TRUE];   
}


- (void)getTimeline
{
    if (twitterClient) return;
	twitterClient = [[TwitterClient alloc] initWithTarget:self action:@selector(timelineDidReceive:obj:)];
    
    insertPosition = 0;
    
    NSMutableDictionary *param = [NSMutableDictionary dictionary];

    int since_id = 0;
    NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"username"];
    for (int i = 0; i < [timeline countStatuses]; ++i) {
        Status* sts = [timeline statusAtIndex:i];
        if ([sts.user.screenName caseInsensitiveCompare:username] != NSOrderedSame) {
            since_id = sts.statusId;
            break;
        }
    }
    
    if (since_id) {
        [param setObject:[NSString stringWithFormat:@"%d", since_id] forKey:@"since_id"];
        [param setObject:@"200" forKey:@"count"];
    }
    
    [twitterClient getTimeline:tweetType params:param];
}

- (void)timelineDidReceive:(TwitterClient*)sender obj:(NSObject*)obj
{
    twitterClient = nil;
    [loadCell.spinner stopAnimating];
   
    if (obj == nil) {
        return;
    }
    
    NSArray *ary = nil;
    if ([obj isKindOfClass:[NSArray class]]) {
        ary = (NSArray*)obj;
    }
    else {
        return;
    }
    
    int unread = 0;
    NSLog(@"Received %d messages on tab %d", [ary count], tweetType);
    
    Status* lastStatus = [timeline lastStatus];
    if ([ary count]) {
        sqlite3* database = [DBConnection getSharedDatabase];
        char *errmsg; 
        sqlite3_exec(database, "BEGIN", NULL, NULL, &errmsg); 
        
        // Add messages to the timeline
        for (int i = [ary count] - 1; i >= 0; --i) {
            NSDictionary *dic = (NSDictionary*)[ary objectAtIndex:i];
            if (![dic isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            sqlite_int64 statusId = [[[ary objectAtIndex:i] objectForKey:@"id"] longLongValue];
            if (![Status isExists:statusId type:tweetType]) {
                Status* sts = [Status statusWithJsonDictionary:[ary objectAtIndex:i] type:tweetType];
                if (sts.createdAt < lastStatus.createdAt) {
                    // Ignore stale message
                    continue;
                }
                [sts insertDB];
                sts.unread = true;
                
                [timeline insertStatus:sts atIndex:insertPosition];
                ++unread;
            }
        }
        
        sqlite3_exec(database, "COMMIT", NULL, NULL, &errmsg); 
    }

    if ([controller respondsToSelector:@selector(timelineDidUpdate:count:insertAt:)]) {
        [controller timelineDidUpdate:self count:unread insertAt:insertPosition];
	}
}

- (void)twitterClientDidFail:(TwitterClient*)sender error:(NSString*)error detail:(NSString*)detail
{
    twitterClient = nil;
    [loadCell.spinner stopAnimating];
    
    if ([controller respondsToSelector:@selector(timelineDidFailToUpdate:position:)]) {
        [controller timelineDidFailToUpdate:self position:insertPosition];
    }
    
    if (sender.statusCode == 401) {
        GogoTwitterAppDelegate *appDelegate = (GogoTwitterAppDelegate*)[UIApplication sharedApplication].delegate;
        [appDelegate openSettingsView];
    }

    //
    // Save alert view to static pointer to avoid displaying alert view many times at the same time.
    //
    if (sAlert) return;
    
    sAlert = [[UIAlertView alloc] initWithTitle:error
                                        message:detail
                                       delegate:self
                              cancelButtonTitle:@"Close"
                              otherButtonTitles: nil];
    [sAlert show];	
    [sAlert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonInde
{
    sAlert = nil;
}

@end
