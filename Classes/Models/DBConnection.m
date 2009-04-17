#import "DBConnection.h"
#import "Statement.h"
#import "TimeUtils.h"
#import "TwitterFonAppDelegate.h"

static sqlite3*             theDatabase = nil;

#define MAIN_DATABASE_NAME @"db1.4.sql"

//#define TEST_DELETE_TWEET

#ifdef TEST_DELETE_TWEET
const char *delete_tweets = 
"BEGIN;"
//"DELETE FROM statuses;"
//"DELETE FROM direct_messages;"
//"DELETE FROM images;"
//"DELETE FROM statuses WHERE type = 0 and id > (SELECT id FROM statuses WHERE type = 0 ORDER BY id DESC LIMIT 1 OFFSET 1);"
//"DELETE FROM statuses WHERE type = 1 and id > (SELECT id FROM statuses WHERE type = 1 ORDER BY id DESC LIMIT 1 OFFSET 1);"
//"DELETE FROM direct_messages WHERE id > (SELECT id FROM direct_messages ORDER BY id DESC LIMIT 1 OFFSET 10);"
"COMMIT";
#endif

@implementation DBConnection

+ (sqlite3*)openDatabase:(NSString*)dbFilename
{
    sqlite3* instance;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:dbFilename];
    // Open the database. The database was prepared outside the application.
    if (sqlite3_open([path UTF8String], &instance) != SQLITE_OK) {
        // Even though the open failed, call close to properly clean up resources.
        NSString *msg = [NSString stringWithUTF8String:sqlite3_errmsg(instance)];
        [[TwitterFonAppDelegate getAppDelegate] alert:@"Failed to open database" message:msg];
        NSLog(@"Failed to open database. (%@)", msg);
        sqlite3_close(instance);
        instance = nil;
    }
    
    return instance;
}

+ (sqlite3*)getSharedDatabase
{
    if (theDatabase == nil) {

        theDatabase = [self openDatabase:MAIN_DATABASE_NAME];
        if (theDatabase == nil) {
            [DBConnection createEditableCopyOfDatabaseIfNeeded:true];
            [[TwitterFonAppDelegate getAppDelegate] alert:@"Local cache error" 
                                                  message:@"Local cache database has been corrupted. Re-created new database."];
        }

#ifdef TEST_DELETE_TWEET
        char *errmsg;
        if (sqlite3_exec(theDatabase, delete_tweets, NULL, NULL, &errmsg) != SQLITE_OK) {
            NSAssert1(0, @"Error: failed to cleanup chache (%s)", errmsg);
        }
#endif
    }
    return theDatabase;
}

+ (void)closeDatabase
{
    if (theDatabase) {       
        sqlite3_close(theDatabase);
    }
}

+ (void)migrate:(NSString*)dbname to:(NSString*)newdbname queries:(NSString*)query_file
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *oldDBPath = [documentsDirectory stringByAppendingPathComponent:dbname];
    NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:newdbname];    
    
    BOOL success = [fileManager fileExistsAtPath:oldDBPath];
    if (success) {
        sqlite3 *oldDB = [DBConnection openDatabase:dbname];
        char *errmsg;
        NSString *migrateSQL = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:query_file];
        NSData *sqldata = [fileManager contentsAtPath:migrateSQL];
        NSString *sql = [[[NSString alloc] initWithData:sqldata encoding:NSUTF8StringEncoding] autorelease];
        if (sqlite3_exec(oldDB, [sql UTF8String], NULL, NULL, &errmsg) == SQLITE_OK) {
            // succeeded to update.
            [fileManager moveItemAtPath:oldDBPath toPath:writableDBPath error:&error];
            NSLog(@"Updated database (%@)", query_file);
            return;
        }
        NSLog(@"Failed to update database (Reason: %s). Discard %@ data...", errmsg, dbname);
        [fileManager removeItemAtPath:oldDBPath error:&error];
    }    
}

// Creates a writable copy of the bundled default database in the application Documents directory.
+ (void)createEditableCopyOfDatabaseIfNeeded:(BOOL)force
{
    // First, test for existence.
    BOOL success;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:MAIN_DATABASE_NAME];
    
    [DBConnection migrate:@"db1.2.sql" to:@"db1.3.sql" queries:@"update_v12_to_v13.sql"];
    [DBConnection migrate:@"db1.3.sql" to:@"db1.4.sql" queries:@"update_v13_to_v14.sql"];
    
    if (force) {
        [fileManager removeItemAtPath:writableDBPath error:&error];
    }
    
    // No exists any database file. Create new one.
    //
    success = [fileManager fileExistsAtPath:writableDBPath];
    if (success) return;
    // The writable database does not exist, so copy the default to the appropriate location.
    NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:MAIN_DATABASE_NAME];
    success = [fileManager copyItemAtPath:defaultDBPath toPath:writableDBPath error:&error];
    if (!success) {
        NSAssert1(0, @"Failed to create writable database file with message '%@'.", [error localizedDescription]);
    }
}

+ (void)beginTransaction
{
    char *errmsg;     
    sqlite3_exec(theDatabase, "BEGIN", NULL, NULL, &errmsg);     
}

+ (void)commitTransaction
{
    char *errmsg;
    Stopwatch *sw = [Stopwatch stopwatch];
    sqlite3_exec(theDatabase, "COMMIT", NULL, NULL, &errmsg);     
    [sw lap:@"COMMIT"];
}

+ (Statement*)statementWithQuery:(const char *)sql
{
    Statement* stmt = [Statement statementWithDB:theDatabase query:sql];
    return stmt;
}

+ (void)alert
{
    NSString *sqlite3err = [NSString stringWithUTF8String:sqlite3_errmsg(theDatabase)];
    [[TwitterFonAppDelegate getAppDelegate] alert:@"Local cache db error" message:sqlite3err];
}

@end
