#import "User.h"
#import "DBConnection.h"
#import "StringUtil.h"
#import "UserStore.h"

@implementation User

@synthesize userId;
@synthesize name;
@synthesize screenName;
@synthesize location;
@synthesize description;
@synthesize url;
@synthesize followersCount;
@synthesize profileImageUrl;
@synthesize protected;
@synthesize friendsCount;
@synthesize statusesCount;
@synthesize favoritesCount;
@synthesize following;
@synthesize notifications;
@synthesize needUpdate;

- (void)checkUpdate:(User*)user
{
    needUpdate = false;
    
    if (![profileImageUrl isEqualToString:user.profileImageUrl]) {
        self.profileImageUrl = user.profileImageUrl;
        needUpdate = true;
    }
    if (![screenName isEqualToString:user.screenName]) {
        self.screenName = user.screenName;
        needUpdate = true;
    }
    if (![name isEqualToString:user.name]) {
        self.name = user.name;
        needUpdate = true;
    }
    if (![location isEqualToString:user.location]) {
        self.location = user.location;
        needUpdate = true;
    }
    if (![description isEqualToString:user.description]) {
        self.description = user.description;
        needUpdate = true;
    }
    if (![url isEqualToString:user.url]) {
        self.url = user.url;
        needUpdate = true;
    }
    if (protected != user.protected) {
        self.protected = user.protected;
        needUpdate = true;
    }
    if (followersCount != user.followersCount) {
        self.followersCount = user.followersCount;
        needUpdate = true;
    }
    
    self.friendsCount   = user.friendsCount;
    self.statusesCount  = user.statusesCount;
    self.favoritesCount = user.favoritesCount;
    self.following      = user.following;
}

- (void)initWithJsonDictionary:(NSDictionary*)dic
{
    [name release];
    [screenName release];
    [location release];
    [description release];
    [url release];
    [profileImageUrl release];
    
    userId          = [[dic objectForKey:@"id"] longValue];
    
    name            = [dic objectForKey:@"name"];
	screenName      = [dic objectForKey:@"screen_name"];
	location        = [dic objectForKey:@"location"];
	description     = [dic objectForKey:@"description"];
	url             = [dic objectForKey:@"url"];
    profileImageUrl = [dic objectForKey:@"profile_image_url"];

    followersCount  = ([dic objectForKey:@"followers_count"] == [NSNull null]) ? 0 : [[dic objectForKey:@"followers_count"] longValue];
    protected       = ([dic objectForKey:@"protected"]       == [NSNull null]) ? 0 : [[dic objectForKey:@"protected"] boolValue];
    
    friendsCount    = ([dic objectForKey:@"friends_count"]   == [NSNull null]) ? 0 : [[dic objectForKey:@"friends_count"] longValue];
    statusesCount   = ([dic objectForKey:@"statuses_count"]  == [NSNull null]) ? 0 : [[dic objectForKey:@"statuses_count"] longValue];
    favoritesCount  = ([dic objectForKey:@"favourites_count"]  == [NSNull null]) ? 0 : [[dic objectForKey:@"favourites_count"] longValue];
    following       = ([dic objectForKey:@"following"]       == [NSNull null]) ? 0 : [[dic objectForKey:@"following"] boolValue];
    notifications   = ([dic objectForKey:@"notifications"]   == [NSNull null]) ? 0 : [[dic objectForKey:@"notifications"] boolValue];
    
    if ((id)name == [NSNull null]) name = @"";
    if ((id)screenName == [NSNull null]) screenName = @"";
    if ((id)location == [NSNull null]) location = @"";
    if ((id)description == [NSNull null]) description = @"";
    if ((id)url == [NSNull null]) url = @"";
    if ((id)profileImageUrl == [NSNull null]) profileImageUrl = @"";
    
    [name retain];
    [screenName retain];
    location = [[location unescapeHTML] retain];
    description = [[description unescapeHTML] retain];
    [url retain];
    [profileImageUrl retain];
}

- (void)updateWithJSonDictionary:(NSDictionary*)dic
{
    User *u = [[User alloc] init];
    [u initWithJsonDictionary:dic];
    [self checkUpdate:u];
    [u release];
}

- (User*)initWithSearchResult:(NSDictionary*)dic
{
	self = [super init];
	
	userId          = [[dic objectForKey:@"from_user_id"] longValue];
    
    name            = [dic objectForKey:@"from_user"];
	screenName      = [dic objectForKey:@"from_user"];
	location        = @"";
	url             = @"";
    followersCount  = 0;
    profileImageUrl = [dic objectForKey:@"profile_image_url"];
    protected       = false;
    description     = @"";
    
    if ((id)name == [NSNull null]) name = @"";
    if ((id)screenName == [NSNull null]) screenName = @"";
    if ((id)profileImageUrl == [NSNull null]) profileImageUrl = @"";
    [name retain];
    [screenName retain];
    [profileImageUrl retain];
	
	return self;
}

+ (User*)userWithId:(int)id
{
    User *user = [UserStore getUserWithId:(int)id];
    
    if (user) return user;
    
    static Statement *stmt = nil;
    if (stmt == nil) {
        stmt = [DBConnection statementWithQuery:"SELECT * FROM users WHERE user_id = ?"];
        [stmt retain];
    }
    
    [stmt bindInt64:id forIndex:1];
    int ret = [stmt step];
    if (ret != SQLITE_ROW) {
        [stmt reset];
        return nil;
    }
    
    user = [[[User alloc] init] autorelease];
    user.userId           = [stmt getInt32:0];
    user.name             = [stmt getString:1];
    user.screenName       = [stmt getString:2];
    user.location         = [stmt getString:3];
    user.description      = [stmt getString:4];
    user.url              = [stmt getString:5];
    user.followersCount   = [stmt getInt32:6];
    user.profileImageUrl  = [stmt getString:7];
    user.protected        = [stmt getInt32:8] ? true : false;

    [stmt reset];
    [UserStore setUser:user];
    return user;
}

+ (User*)userWithJsonDictionary:(NSDictionary*)dic
{
    User *u = [UserStore getUser:[dic objectForKey:@"screen_name"]];
    if (u) {
        [u updateWithJSonDictionary:dic];
        return u;
    }
    
    u = [User userWithId:[[dic objectForKey:@"id"] longValue]];
    
    if (u) {
        [UserStore setUser:u];
        [u updateWithJSonDictionary:dic];
        return u;
    }
    
    u = [[User alloc] init];
    [u initWithJsonDictionary:dic];
    u.needUpdate = true;
    [UserStore setUser:u];
    return u;
}

+ (User*)userWithSearchResult:(NSDictionary*)dic
{
    User *u = [UserStore getUser:[dic objectForKey:@"from_user"]];
    if (u) return u;
    
    u = [[User alloc] initWithSearchResult:dic];
    [UserStore setUser:u];
    return u;    
}

- (void)updateDB
{
    if (!needUpdate) return;
    
    static Statement *stmt = nil;
    if (stmt == nil) {
        stmt = [DBConnection statementWithQuery:"REPLACE INTO users VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)"];
        [stmt retain];
    }
    [stmt bindInt32:userId              forIndex:1];
    [stmt bindString:name               forIndex:2];
    [stmt bindString:screenName         forIndex:3];
    [stmt bindString:location           forIndex:4];
    [stmt bindString:description        forIndex:5];
    [stmt bindString:url                forIndex:6];
    [stmt bindInt32:followersCount      forIndex:7];
    [stmt bindString:profileImageUrl    forIndex:8];
    [stmt bindInt32:protected           forIndex:9];

    if ([stmt step] != SQLITE_DONE) {
        [DBConnection alert];
    }
    [stmt reset];
}

- (void)dealloc
{
    [url release];
    [location release];
    [description release];
    [name release];
    [screenName release];
    [profileImageUrl release];
   	[super dealloc];
}

@end
