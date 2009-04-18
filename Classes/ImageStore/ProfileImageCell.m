//
//  ProfileImageCell.m
//  TwitterFon
//
//  Created by kaz on 12/22/08.
//  Copyright 2008 naan studio. All rights reserved.
//

#import "ProfileImageCell.h"
#import "GogoTwitterAppDelegate.h"

@implementation ProfileImageCell

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
        _receiver = [[ImageStoreReceiver alloc] init];
    }
    return self;
}

- (void)updateImage:(UIImage*)image
{
    // Perhaps, you need re-implement on deliver class
    self.image = image;
    [self setNeedsDisplay];
    [self setNeedsLayout];    
}

- (UIImage*)getProfileImage:(NSString*)url isLarge:(BOOL)flag
{
    if (_profileImageUrl != url) {
        [_profileImageUrl release];
    }
    _profileImageUrl = [url copy];
    
    ImageStore *store = [GogoTwitterAppDelegate getAppDelegate].imageStore;
    UIImage *image = [store getProfileImage:url isLarge:flag delegate:_receiver];
    _receiver.imageContainer = self;
    return image;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    ImageStore *store = [GogoTwitterAppDelegate getAppDelegate].imageStore;
    [store removeDelegate:_receiver forURL:_profileImageUrl];
    _receiver.imageContainer = nil;
}

- (void)dealloc {
    _receiver.imageContainer = nil;
    ImageStore *store = [GogoTwitterAppDelegate getAppDelegate].imageStore;
    [store removeDelegate:_receiver forURL:_profileImageUrl];
    [_profileImageUrl release];
    [_receiver release];
    [super dealloc];
}


@end
