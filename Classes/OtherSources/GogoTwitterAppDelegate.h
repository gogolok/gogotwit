/*
 *  Copyright (c) 2009 Robert Gogolok <gogolok+gogotwitter@googlemail.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

//
//  TwitterFonAppDelegate.h
//  TwitterFon
//
//  Created by kaz on 7/13/08.
//  Copyright naan studio 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PostViewController.h"
#import "WebViewController.h"
#import "SettingsViewController.h"
#import "ImageStore.h"
#import "Status.h"

typedef enum {
    TAB_FRIENDS,
    TAB_REPLIES,
    TAB_MESSAGES,
    TAB_FAVORITES,
    TAB_SEARCH,
} TAB_ITEM;

@interface GogoTwitterAppDelegate : NSObject <UIApplicationDelegate, UITabBarControllerDelegate> {
	IBOutlet UIWindow*              window;
	IBOutlet UITabBarController*    tabBarController;

    PostViewController*             postView;
    WebViewController*              webView;
    SettingsViewController*         settingsView;
    ImageStore*                     imageStore;
    int                             selectedTab;
    BOOL                            initialized;
    NSTimeInterval                  autoRefreshInterval;
    NSTimer*                        autoRefreshTimer;
    NSDate*                         lastRefreshDate;
    
    NSString*                       screenName;

    BOOL                                needOptimizeDB;
    IBOutlet UIWindow*                  HUD;
    IBOutlet UIActivityIndicatorView*   spinner;
}

- (IBAction)post:(id)sender;

- (void)postTweetDidSucceed:(NSDictionary*)status;
- (void)sendMessageDidSucceed:(NSDictionary*)message;
- (void)postViewAnimationDidFinish:(BOOL)isDirectMessage;

- (void) openSettingsView;
- (void) closeSettingsView;
- (void) openWebView:(NSString*)url on:(UINavigationController*)viewController;
- (void) openWebView:(NSString*)url;
- (void) search:(NSString*)query;

- (void)openLinksViewController:(NSString*)text;
- (void)toggleFavorite:(Status*)status;

- (void)alert:(NSString*)title message:(NSString*)detail;

+ (BOOL)isMyScreenName:(NSString*)screen_name;
+ (GogoTwitterAppDelegate*)getAppDelegate;

@property (nonatomic, readonly) UIWindow*           window;
@property (nonatomic, assign) PostViewController*   postView;
@property (nonatomic, readonly) ImageStore*         imageStore;
@property (nonatomic, assign) int                   selectedTab;
@property (nonatomic, retain) NSString*             screenName;

@end
