//
//  Statement.m
//  TwitterFon
//
//  Created by kaz on 12/21/08.
//  Copyright 2008 naan studio. All rights reserved.
//

#import "DBConnection.h"
#import "Statement.h"
#import "TimeUtils.h"

//#define DEBUG_QUERY

@implementation Statement

- (id)initWithDB:(sqlite3*)db query:(const char*)sql
{
    self = [super init];
#ifdef DEBUG_QUERY    
    query = [[NSString alloc] initWithUTF8String:sql];
#endif
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        NSLog(@"Failed to prepare statement '%s' (SQL Error: %s)", sql, sqlite3_errmsg(db));
        [DBConnection alert];
    }
    return self;
}

+ (id)statementWithDB:(sqlite3*)db query:(const char*)sql
{
    return [[[Statement alloc] initWithDB:db query:sql] autorelease];
}

- (int)step
{
#ifdef DEBUG_QUERY
    Stopwatch *sw = [Stopwatch stopwatch];
#endif
    int result = sqlite3_step(stmt);
#ifdef DEBUG_QUERY
    if ([sw diff] > 100 * 1000) {
        [sw lap:query];
    }
#endif
    return result;
}

- (void)reset
{
    sqlite3_reset(stmt);
}

- (void)dealloc
{
#ifdef DEBUG_QUERY
    [query release];
#endif
    sqlite3_finalize(stmt);
    [super dealloc];
}

//
//
//
- (NSString*)getString:(int)index
{
    return [NSString stringWithUTF8String:(char*)sqlite3_column_text(stmt, index)];    
}

- (int)getInt32:(int)index
{
    return (int)sqlite3_column_int(stmt, index);
}

- (long long)getInt64:(int)index
{
    return (long long)sqlite3_column_int(stmt, index);
}

- (NSData*)getData:(int)index
{
    int length = sqlite3_column_bytes(stmt, index);
    return [NSData dataWithBytes:sqlite3_column_blob(stmt, index) length:length];    
}

//
//
//
- (void)bindString:(NSString*)value forIndex:(int)index
{
    sqlite3_bind_text(stmt, index, [value UTF8String], -1, SQLITE_TRANSIENT);
}

- (void)bindInt32:(int)value forIndex:(int)index
{
    sqlite3_bind_int(stmt, index, value);
}

- (void)bindInt64:(long long)value forIndex:(int)index
{
    sqlite3_bind_int64(stmt, index, value);
}

- (void)bindData:(NSData*)value forIndex:(int)index
{
    sqlite3_bind_blob(stmt, index, value.bytes, value.length, SQLITE_TRANSIENT);
}
@end
