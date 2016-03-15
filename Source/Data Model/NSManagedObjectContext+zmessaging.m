// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
// 


@import ZMUtilities;

#import <zmessaging/NSManagedObjectContext+zmessaging-Internal.h>
#import "NSManagedObjectContext+tests.h"
#import "ZMManagedObject.h"
#import "ZMUser+Internal.h"
#import "ZMSyncMergePolicy.h"
#import "ZMConversation+Internal.h"
#import "ZMUserDisplayNameGenerator.h"
#import "ZMTracing.h"

#import "ZMConversation+Internal.h"
#import "ZMUserSession.h"
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>
#import <zmessaging/zmessaging-Swift.h>
#import <ZMUtilities/ZMUtilities-Swift.h>

static NSString * const IsSyncContextKey = @"ZMIsSyncContext";
static NSString * const IsSearchContextKey = @"ZMIsSearchContext";
static NSString * const SyncContextKey = @"ZMSyncContext";
static NSString * const UserInterfaceContextKey = @"ZMUserInterfaceContext";
static NSString * const IsRefreshOfObjectsDisabled = @"ZMIsRefreshOfObjectsDisabled";
static NSString * const IsUserInterfaceContextKey = @"ZMIsUserInterfaceContext";
static NSString * const IsSaveDisabled = @"ZMIsSaveDisabled";
static NSString * const IsFailingToSave = @"ZMIsFailingToSave";

static BOOL UsesInMemoryStore;
static NSPersistentStoreCoordinator *sharedPersistentStoreCoordinator;
static NSPersistentStoreCoordinator *inMemorySharedPersistentStoreCoordinator;
static NSString * const ClearPersistentStoreOnStartKey = @"ZMClearPersistentStoreOnStart";
static NSString * const TimeOfLastSaveKey = @"ZMTimeOfLastSave";
static NSString * const FirstEnqueuedSaveKey = @"ZMTimeOfLastSave";
static NSString * const MetadataKey = @"ZMMetadataKey";
static NSString * const FailedToEstablishSessionStoreKey = @"FailedToEstablishSessionStoreKey";


static dispatch_queue_t singletonContextIsolation(void);
static NSManagedObjectContext *SharedUserInterfaceContext = nil;
static id applicationProtectedDataDidBecomeAvailableObserver = nil;

static char* const ZMLogTag ZM_UNUSED = "NSManagedObjectContext";
//
// For testing, we want to use an NSInMemoryStoreType (it's faster).
// The only way for multiple contexts to share the same NSInMemoryStoreType is to share
// the persistent store coordinator.
//


@interface NSManagedObjectContext (CleanUp)

- (void)refreshUnneededObjects;

@end



@implementation NSManagedObjectContext (zmessaging)

static BOOL storeIsReady = NO;

+ (BOOL)needsToPrepareLocalStore
{
    NSError *error = nil;
    NSManagedObjectModel *mom = [self loadManagedObjectModel];
    NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                        URL:[self storeURL]
                                                                                      error:&error];
    
    if (nil != error) {
        ZMLogError(@"Cannot open store metadata: %@", error);
    }
    
    BOOL needsMigration = ![mom isConfiguration:nil compatibleWithStoreMetadata:metadata];
    return needsMigration || [self databaseExistsInCachesDirectory] || [self databaseExistsAndNotReadableDueToEncryption];
}

+ (void)prepareLocalStoreInternalBackingUpCorruptedDatabase:(BOOL)backupCorrputedDatabase completionHandler:(void (^)())completionHandler
{
    dispatch_block_t finally = ^() {
        dispatch_async(dispatch_get_main_queue(), ^{
            storeIsReady = YES;
            if (nil != completionHandler) {
                completionHandler();
            }
        });
    };
    
    //just try to create psc, contexts will be created later when user session is initialized
    if (UsesInMemoryStore) {
        RequireString(inMemorySharedPersistentStoreCoordinator == nil, "In-Memory persistent store was not nil");
        inMemorySharedPersistentStoreCoordinator = [self inMemoryPersistentStoreCoordinator];
        finally();
    }
    else {
        RequireString(sharedPersistentStoreCoordinator == nil, "Shared persistent store was not nil");
        
        // We need to handle the case when the database file is encrypted by iOS and user never entered the passcode
        // We use default core data protection mode NSFileProtectionCompleteUntilFirstUserAuthentication
        // This happens when
        // (1) User has passcode enabled
        // (2) User turns the phone on, but do not enter the passcode yet
        // (3) App is awake on the background due to VoIP push notification
        // We should wait then until the database is becoming available
        if ([self databaseExistsAndNotReadableDueToEncryption]) {
            ZM_WEAK(self);
            NSAssert(applicationProtectedDataDidBecomeAvailableObserver == nil, @"prepareLocalStoreInternalBackingUpCorruptedDatabase: called twice");
            
            applicationProtectedDataDidBecomeAvailableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationProtectedDataDidBecomeAvailable
                                                                  object:nil
                                                                   queue:nil
                                                              usingBlock:^(NSNotification * _Nonnull __unused note) {
                                                                  ZM_STRONG(self);
                                                                  sharedPersistentStoreCoordinator = [self initPersistentStoreCoordinatorBackingUpCorrupedDatabases:backupCorrputedDatabase];
                                                                  finally();
                                                                  [[NSNotificationCenter defaultCenter] removeObserver:applicationProtectedDataDidBecomeAvailableObserver];
                                                                  applicationProtectedDataDidBecomeAvailableObserver = nil;
                                                              }];
        }
        else {
            sharedPersistentStoreCoordinator = [self initPersistentStoreCoordinatorBackingUpCorrupedDatabases:backupCorrputedDatabase];
            finally();
        }
    }
}

+ (void)prepareLocalStoreSync:(BOOL)sync backingUpCorruptedDatabase:(BOOL)backupCorrputedDatabase completionHandler:(void(^)())completionHandler;
{
    (sync ? dispatch_sync : dispatch_async)(singletonContextIsolation(), ^{
        [self prepareLocalStoreInternalBackingUpCorruptedDatabase:backupCorrputedDatabase completionHandler:completionHandler];
    });
}

+ (BOOL)storeIsReady
{
    return storeIsReady;
}

+ (NSPersistentStoreCoordinator *)requirePersistentStoreCoordinatorInternal
{
    NSPersistentStoreCoordinator *psc = UsesInMemoryStore ? inMemorySharedPersistentStoreCoordinator : sharedPersistentStoreCoordinator;
    
    if (psc == nil) {
        [self prepareLocalStoreInternalBackingUpCorruptedDatabase:NO completionHandler:nil];
        psc = UsesInMemoryStore ? inMemorySharedPersistentStoreCoordinator : sharedPersistentStoreCoordinator;
        Require(psc != nil);
    }
    
    return psc;
}

+ (NSPersistentStoreCoordinator *)requirePersistentStoreCoordinator
{
    NSPersistentStoreCoordinator *psc = UsesInMemoryStore ? inMemorySharedPersistentStoreCoordinator : sharedPersistentStoreCoordinator;
    
    if (psc == nil) {
        dispatch_sync(singletonContextIsolation(), ^() {
            [self prepareLocalStoreInternalBackingUpCorruptedDatabase:NO completionHandler:nil];
        });
        psc = UsesInMemoryStore ? inMemorySharedPersistentStoreCoordinator : sharedPersistentStoreCoordinator;
        Require(psc != nil);
    }
    
    return psc;
}

+ (instancetype)createUserInterfaceContext;
{
    __block NSManagedObjectContext *result = nil;
    dispatch_sync(singletonContextIsolation(), ^{
        result = SharedUserInterfaceContext;
        if (result == nil) {
            NSPersistentStoreCoordinator *psc = [self requirePersistentStoreCoordinatorInternal];
            
            result = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [result markAsUIContext];
            [result configureWithPersistentStoreCoordinator:psc];
            result.mergePolicy = [[ZMSyncMergePolicy alloc] initWithMergeType:NSRollbackMergePolicyType];
            SharedUserInterfaceContext = result;
            [result continuouslyCheckForUnsavedChanges];
            (void)result.globalManagedObjectContextObserver;
        }
    });
    return result;
}

+ (void)resetUserInterfaceContext
{
    dispatch_async(singletonContextIsolation(), ^{
        SharedUserInterfaceContext = nil;
    });
}

+ (instancetype)createSyncContext;
{
    NSPersistentStoreCoordinator *psc = [self requirePersistentStoreCoordinator];

    NSManagedObjectContext *moc = [[self alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [moc markAsSyncContext];
    [moc configureWithPersistentStoreCoordinator:psc];
    moc.undoManager = nil;
    moc.mergePolicy = [[ZMSyncMergePolicy alloc] initWithMergeType:NSMergeByPropertyObjectTrumpMergePolicyType];
    return moc;
}

+ (instancetype)createSearchContext;
{
    NSPersistentStoreCoordinator *psc = [self requirePersistentStoreCoordinator];
    
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [moc markAsSearchContext];
    [moc configureWithPersistentStoreCoordinator:psc];
    moc.undoManager = nil;
    moc.mergePolicy = [[ZMSyncMergePolicy alloc] initWithMergeType:NSRollbackMergePolicyType];
    return moc;
}

- (void)configureWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)psc;
{
    RequireString(self.zm_isSyncContext || self.zm_isUserInterfaceContext || self.zm_isSearchContext, "Context is not marked, yet");
    [self createDispatchGroups];
    self.persistentStoreCoordinator = psc;
    [self ensureSingletonsExist];
}

- (BOOL)zm_isSyncContext;
{
    return [self.userInfo[IsSyncContextKey] boolValue];
}

- (BOOL)zm_isUserInterfaceContext;
{
    return [self.userInfo[IsUserInterfaceContextKey] boolValue];
}

- (BOOL)zm_isSearchContext;
{
    return [self.userInfo[IsSearchContextKey] boolValue];
}

- (NSManagedObjectContext*)zm_syncContext
{
    if (self.zm_isSyncContext) {
        return self;
    }
    else {
        UnownedNSObject *unownedContext = self.userInfo[SyncContextKey];
        if (nil != unownedContext) {
            return (NSManagedObjectContext *)unownedContext.unbox;
        }
    }
    
    return nil;
}

- (void)setZm_syncContext:(NSManagedObjectContext *)zm_syncContext
{
    self.userInfo[SyncContextKey] = [[UnownedNSObject alloc] init:zm_syncContext];
}

- (NSManagedObjectContext*)zm_userInterfaceContext
{
    if (self.zm_isUserInterfaceContext) {
        return self;
    }
    else {
        UnownedNSObject *unownedContext = self.userInfo[UserInterfaceContextKey];
        if (nil != unownedContext) {
            return (NSManagedObjectContext *)unownedContext.unbox;
        }
    }
    
    return nil;
}

- (void)setZm_userInterfaceContext:(NSManagedObjectContext *)zm_userInterfaceContext
{
    self.userInfo[UserInterfaceContextKey] = [[UnownedNSObject alloc] init:zm_userInterfaceContext];
}

- (BOOL)zm_isRefreshOfObjectsDisabled;
{
    return [self.userInfo[IsRefreshOfObjectsDisabled] boolValue];
}

- (BOOL)zm_shouldRefreshObjectsWithSyncContextPolicy
{
    return self.zm_isSyncContext && !self.zm_isRefreshOfObjectsDisabled;
}

- (BOOL)zm_shouldRefreshObjectsWithUIContextPolicy
{
    return self.zm_isUserInterfaceContext && !self.zm_isRefreshOfObjectsDisabled;
}

+ (void)setUseInMemoryStore:(BOOL)useInMemoryStore;
{
    UsesInMemoryStore = useInMemoryStore;
}

+ (NSPersistentStoreCoordinator *)inMemoryPersistentStoreCoordinator;
{
    NSManagedObjectModel *mom = [self loadManagedObjectModel];
    NSPersistentStoreCoordinator* persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    
    NSError *error = nil;
    NSPersistentStore *store = [persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType
                                                                        configuration:nil
                                                                                  URL:nil
                                                                              options:nil
                                                                                error:&error];
    
    NSAssert(store != nil, @"Unable to create in-memory Core Data store: %@", error);
    return persistentStoreCoordinator;
}

+ (void)setClearPersistentStoreOnStart:(BOOL)flag;
{
    if (flag) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ClearPersistentStoreOnStartKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:ClearPersistentStoreOnStartKey];
    }
}

+ (void)clearPersistentStoreOnStart;
{
    dispatch_once(&clearStoreOnceToken, ^{
        if ([[NSUserDefaults standardUserDefaults] boolForKey:ClearPersistentStoreOnStartKey]) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:ClearPersistentStoreOnStartKey];
            [self removePersistentStoreFromFilesystemAndCopyToBackup:NO];
        }
    });
}

- (NSMutableSet *)zm_failedToEstablishSessionStore
{
    if (!self.zm_isSyncContext) {
        return nil;
    }
    
    if (nil == self.userInfo[FailedToEstablishSessionStoreKey]) {
        self.userInfo[FailedToEstablishSessionStoreKey] = [NSMutableSet set];
    }
    
    return self.userInfo[FailedToEstablishSessionStoreKey];
}

/// @param copyToBackup: if true, will dump the database to a safe location before deleting it
+ (void)removePersistentStoreFromFilesystemAndCopyToBackup:(BOOL)copyToBackup;
{
    // Enumerate all files in the store directory and find the ones that match the store name.
    // We need to do this, because the store consists of several files.
    
    NSURL *const storeFileURL = [self storeURL];
    NSString * const storeName = [storeFileURL lastPathComponent];
    NSURL *storeFolder;
    if (![storeFileURL getResourceValue:&storeFolder forKey:NSURLParentDirectoryURLKey error:NULL]) {
        return;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if(copyToBackup) {
        
        NSURL *rootFolder;
        if ([storeFolder getResourceValue:&rootFolder forKey:NSURLParentDirectoryURLKey error:NULL]) {
            NSString *timeStamp = [NSString stringWithFormat:@"DB-%lu.bak", (unsigned long)(1000 *[NSDate date].timeIntervalSince1970)];
            NSURL *backupFolder = [rootFolder URLByAppendingPathComponent:timeStamp];
            [backupFolder setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
            
            NSError *copyError;
            if(![fm copyItemAtURL:storeFolder toURL:backupFolder error:&copyError]) {
                ZMLogError(@"Failed to copy to backup folder: %@", copyError);
            }
            else {
                ZMLogWarn(@"Copied backup of corrupted DB to: %@", backupFolder.absoluteString);
            }
        }
        else {
            ZMLogError(@"Failed to copy to backup folder: can't access root folder of %@", storeFolder);
        }
    }
    
    for (NSURL *fileURL in [fm enumeratorAtURL:storeFolder includingPropertiesForKeys:@[NSURLNameKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil]) {
        NSError *error = nil;
        NSString *name;
        if (! [fileURL getResourceValue:&name forKey:NSURLNameKey error:&error]) {
            ZMLogDebug(@"Skipping item \"%@\" because we can't get the name: %@", fileURL.path, error);
            continue;
        }
        // "external binary data" is stored inside ".storeName_SUPPORT"
        if ([name hasPrefix:storeName] ||
            [name hasPrefix:[NSString stringWithFormat:@".%@_", storeName]])
        {
            if (! [fm removeItemAtURL:fileURL error:&error]) {
                ZMLogError(@"Unable to delete item \"%@\": %@", fileURL.path, error);
            }
        }
    }
}

static dispatch_once_t storeURLOnceToken;
static dispatch_once_t clearStoreOnceToken;

+ (void)resetSharedPersistentStoreCoordinator;
{
    inMemorySharedPersistentStoreCoordinator = nil;
    sharedPersistentStoreCoordinator = nil;
    storeURLOnceToken = 0;
    clearStoreOnceToken = 0;
}

+ (NSPersistentStoreCoordinator *)onDiskPersistentStoreCoordinator
{
    return sharedPersistentStoreCoordinator;
}

+ (NSPersistentStoreCoordinator *)initPersistentStoreCoordinatorBackingUpCorrupedDatabases:(BOOL)backupCorruptedDatabase;
{
    [self clearPersistentStoreOnStart];
    
    [self moveDatabaseFromCachesToApplicationSupportIfNeeded];
    
    NSError *error = nil;
    NSManagedObjectModel *mom = [self loadManagedObjectModel];
    NSPersistentStoreCoordinator* psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    
    NSError *metadataError = nil;
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:[self storeURL] error:&metadataError];
    
    // Something happened while reading the current database metadata
    if (nil != metadataError) {
        ZMLogError(@"Error reading store metadata: %@", metadataError);
    }
    
    NSString *oldModelVersion = [sourceMetadata[NSStoreModelVersionIdentifiersKey] firstObject];
    
    // Between non-E2EE and E2EE we should not migrate the DB for privacy reasons.
    // We know that the old mom is a version supporting E2EE when it
    // contains the 'ClientMessage' entity or is at least of version 1.25
    BOOL otrBuild = [[sourceMetadata[NSStoreModelVersionHashesKey] allKeys] containsObject:ZMClientMessage.entityName];
    BOOL atLeastVersion1_25 = oldModelVersion != nil &&  [oldModelVersion compare:@"1.25" options:NSNumericSearch] != NSOrderedDescending;
    
    // Unfortunately the 1.24 Release has a mom version of 1.3 but we do not want to migrate from it
    // This additional check is also important as the string comparison with NSNumericSearch will return
    // NSOrderedAscending for 1.25 and 1.30 but NSOrderedDescending for 1.25 and 1.3
    NSString *currentModelIdentifier = mom.versionIdentifiers.anyObject;
    BOOL newerOTRVersion = atLeastVersion1_25 && ![oldModelVersion isEqualToString:@"1.3"];
    BOOL shouldMigrate = otrBuild || newerOTRVersion;
    BOOL isSameAsCurrent =  [currentModelIdentifier isEqualToString:oldModelVersion]; // this is used to avoid migrating internal
    // builds when we update the DB internally
    // between releases
    
    if (shouldMigrate && !isSameAsCurrent) {
        NSDictionary *options = [self persistentStoreOptionsDictionarySupportingMigration:YES];
        NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self storeURL] options:options error:&error];
        RequireString(nil != store, "Unable to perform migration and create SQLite Core Data store: %lu", (long)error.code);
        if (nil != store) {
            return psc;
        }
    }
    [self addPersistentStoreBackingUpCorruptedDatabases:backupCorruptedDatabase toPSC:psc];
    return psc;
}

+ (void)addPersistentStoreBackingUpCorruptedDatabases:(BOOL)backupCorruptedDatabase toPSC:(NSPersistentStoreCoordinator *)psc
{
    // If we do not have a store by now, we are either already at the current version, or updating from a non E2EE build, or the migration failed.
    // Either way we will try to create a persistent store without perfoming any migrations.
    NSDictionary *options = [self persistentStoreOptionsDictionarySupportingMigration:NO];
    NSError *error;
    
    NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self storeURL] options:options error:&error];
    if (store == nil) {
        // Something really wrong
        // Try to remove the store and create from scratch
        if(backupCorruptedDatabase) {
            NSString *errorString = [NSString stringWithFormat:@"Error in opening database: %@", error];
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Database corruption" message:errorString delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
                [alert show];
            });
        }
        ZMLogError(@"Failed to open database. Corrupted database? Error: %@", error);
        
        [self removePersistentStoreFromFilesystemAndCopyToBackup:backupCorruptedDatabase];
        // Re-try to add the store
        store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[self storeURL] options:options error:&error];
    }
    RequireString(store != nil, "Unable to create SQLite Core Data store: %lu", (long) error.code);
}


+ (NSDictionary *)persistentStoreOptionsDictionarySupportingMigration:(BOOL)supportsMigration
{
    return @{
             // https://www.sqlite.org/pragma.html
             NSSQLitePragmasOption: @{ @"journal_mode": @"WAL", @"synchronous" : @"FULL" },
             NSMigratePersistentStoresAutomaticallyOption: @(supportsMigration),
             NSInferMappingModelAutomaticallyOption: @(supportsMigration)
             };
}

+ (NSURL *)urlForDatabaseDirectoryInSearchPathDirectory:(NSSearchPathDirectory)searchPathDirectory
{
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL * const directory = [fm URLForDirectory:searchPathDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    RequireString(directory != nil, "Failed to get or create directory: %lu", (long) error.code);
    NSString *identifier = [NSBundle mainBundle].bundleIdentifier;
    if (identifier == nil) {
        identifier = ((NSBundle *)[NSBundle bundleForClass:[ZMUser class]]).bundleIdentifier;
    }
    
    return [directory URLByAppendingPathComponent:identifier];
}

+ (NSURL *)storeURLInDirectory:(NSSearchPathDirectory)directory;
{
    NSError *error;
    NSURL *storeURL = [self urlForDatabaseDirectoryInSearchPathDirectory:directory];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (! [fm fileExistsAtPath:storeURL.path]) {
        short const permissions = 0700;
        NSDictionary *attr = @{NSFilePosixPermissions: @(permissions)};
        RequireString([fm createDirectoryAtURL:storeURL withIntermediateDirectories:YES attributes:attr error:&error],
                      "Failed to create subdirectory in searchpath directory: %lu, error: %lu", (unsigned long)directory,  (unsigned long) error.code);
    }
    
    // Make sure this is not backed up:
    if (! [storeURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error]) {
        ZMLogError(@"Error excluding %@ from backup %@", storeURL.path, error);
    }
    
    NSString *storeFilename = @"store.wiredatabase";
    return [storeURL URLByAppendingPathComponent:storeFilename];
}

+ (NSURL *)storeURL;
{
    return [self storeURLInDirectory:NSApplicationSupportDirectory];
}

+ (NSURL *)cachesDirectoryStoreURL;
{
    return [self storeURLInDirectory:NSCachesDirectory];
}

/// If this is false it means we have succesfully moved the database from the caches directory to the application support directory
+ (BOOL)databaseExistsInCachesDirectory
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *databaseURL = [self cachesDirectoryStoreURL];
    BOOL fileExists = [fm fileExistsAtPath:databaseURL.path isDirectory:nil];
    return fileExists;
}

/// Checks if database is created, but it is still locked with iOS file protection
+ (BOOL)databaseExistsAndNotReadableDueToEncryption
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *databaseURL = [self storeURL];
    BOOL fileExists = [fm fileExistsAtPath:databaseURL.path isDirectory:nil];
    
    NSError *readError = nil;
    [NSFileHandle fileHandleForReadingFromURL:databaseURL error:&readError];
    
    BOOL result = fileExists && readError != nil;
    if (result) {
        ZMLogError(@"databaseExistsAndNotReadableDueToEncryption=true, error=%@", readError);
    }
    
    return result;
}

+ (BOOL)moveDatabaseFromCachesToApplicationSupportIfNeeded
{
    // we need to move if true
    if ([self databaseExistsInCachesDirectory]) {
        
        NSError *error;
        NSURL *toURL   = [self storeURL];
        NSURL *fromURL = [self cachesDirectoryStoreURL];
        NSFileManager *fm = [NSFileManager defaultManager];
        
        ZMLogDebug(@"Starting to move database from path: %@ to path: %@", fromURL, toURL);
        
        for (NSString *extension in self.databaseFileExtensions) {
            
            NSString *destinationPath = [toURL.path stringByAppendingString:extension];
            NSString *sourcePath = [fromURL.path stringByAppendingString:extension];
            
            if (! [fm fileExistsAtPath:sourcePath isDirectory:nil]) {
                continue;
            }
            
            if (! [fm moveItemAtPath:sourcePath toPath:destinationPath error:&error]) {
                ZMLogError(@"Failed to copy database from caches: %@ to application support directory: %@ error: %@", sourcePath, destinationPath, error);
                return NO;
            }
        }
        
        [self moveExternalBinaryFilesFromCachesToApplicationSupport];
    }
    
    return YES;
}

+ (void)moveExternalBinaryFilesFromCachesToApplicationSupport;
{
    NSURL *const cachesURL = [self cachesDirectoryStoreURL];
    NSString * const storeName = [cachesURL.URLByDeletingPathExtension lastPathComponent];
    NSURL *parentURL = cachesURL.URLByDeletingLastPathComponent;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:parentURL.path isDirectory:&isDirectory] || !isDirectory) {
        return;
    }

    NSURL *toURLParent = [self storeURL].URLByDeletingLastPathComponent;
    NSString *supportExtension = [NSString stringWithFormat:@".%@_SUPPORT", storeName];
    NSURL *fromURL = [parentURL URLByAppendingPathComponent:supportExtension];
    NSURL *toURL = [toURLParent URLByAppendingPathComponent:supportExtension];
    
    if ([fm fileExistsAtPath:fromURL.path]) {
        NSError *error = nil;
        if (! [fm moveItemAtURL:fromURL toURL:toURL error:&error]) {
            ZMLogError(@"Unable to move external binary data item from: %@ to: %@", fromURL.path, error);
        }
    }
}

+ (NSArray <NSString *> *)databaseFileExtensions
{
    return @[@"", @"-wal", @"-shm"];
}

- (BOOL)saveOrRollback;
{
    return [self saveOrRollbackIgnoringChanges:NO];
}

- (BOOL)forceSaveOrRollback;
{
    return [self saveOrRollbackIgnoringChanges:YES];
}

- (BOOL)saveOrRollbackIgnoringChanges:(BOOL)shouldIgnoreChanges;
{
    if(self.userInfo[IsSaveDisabled]) {
        return YES;
    }
    
    ZMLogDebug(@"%@ <%@: %p>.", NSStringFromSelector(_cmd), self.class, self);
    
    NSDictionary *oldMetadata = [self.persistentStoreCoordinator metadataForPersistentStore:[self firstPersistentStore]];
    [self makeMetadataPersistent];
    
    if (self.userInfo[IsFailingToSave]) {
        [self rollbackWithOldMetadata:oldMetadata];
        return NO;
    }
    
    // We need to save even if hasChanges is NO as long as the callState changes. An empty save will result in an empty did-save notification.
    // That notification in turn will result in a merge, even if it is empty, and thus merge the call state.
    if (self.zm_hasChanges || shouldIgnoreChanges) {
        NSError *error;
        ZMLogDebug(@"Saving <%@: %p>.", self.class, self);
        self.timeOfLastSave = [NSDate date];
        ZMSTimePoint *tp = [ZMSTimePoint timePointWithInterval:10 label:[NSString stringWithFormat:@"Saving context %@", self.zm_isSyncContext ? @"sync": @"ui"]];
        if (! [self save:&error]) {
            ZMLogError(@"Failed to save: %@", error);
            [self rollbackWithOldMetadata:oldMetadata];
            [tp warnIfLongerThanInterval];
            return NO;
        }
        [tp warnIfLongerThanInterval];
        [self refreshUnneededObjects];
    }
    else {
        ZMLogDebug(@"Not saving because there is no change");
    }
    return YES;
}

- (void)rollbackWithOldMetadata:(NSDictionary *)oldMetadata;
{
    [self rollback];
    [self.persistentStoreCoordinator setMetadata:oldMetadata forPersistentStore:[self firstPersistentStore]];
    if (self.zm_isSyncContext) {
        [self.zm_cryptKeyStore.box resetSessionsRequiringSave];
    }
}

- (NSDate *)timeOfLastSave;
{
    return self.userInfo[TimeOfLastSaveKey];
}

- (void)setTimeOfLastSave:(NSDate *)date;
{
    if (date != nil) {
        self.userInfo[TimeOfLastSaveKey] = date;
    } else {
        [self.userInfo removeObjectForKey:TimeOfLastSaveKey];
    }
}

- (NSDate *)firstEnqueuedSave {
    return self.userInfo[FirstEnqueuedSaveKey];
}

- (void)setFirstEnqueuedSave:(NSDate *)date;
{
    if (date != nil) {
        self.userInfo[FirstEnqueuedSaveKey] = date;
    } else {
        [self.userInfo removeObjectForKey:FirstEnqueuedSaveKey];
    }
}

- (void)enqueueDelayedSave;
{
    [self enqueueDelayedSaveWithGroup:nil];
}

- (BOOL)saveIfTooManyChanges
{
    NSUInteger const changeCount = self.deletedObjects.count + self.insertedObjects.count + self.updatedObjects.count;
    NSUInteger const threshold = 200;
    if (threshold < changeCount) {
        ZMTraceObjectContextEnqueueSave(1, 0, (int) changeCount);
        ZMLogDebug(@"enqueueSaveIfTooManyChanges: calling -saveOrRollback synchronuously because change count is %llu.",
                   (unsigned long long) changeCount);
        [self saveOrRollback];
        return YES;
    }
    return NO;
}

- (BOOL)saveIfDelayIsTooLong
{
    if (self.firstEnqueuedSave == nil) {
        self.firstEnqueuedSave = [NSDate date];
    } else {
        if ([[NSDate date] timeIntervalSinceDate:self.firstEnqueuedSave] > 0.25) {
            [self saveOrRollback];
            self.firstEnqueuedSave = nil;
            return YES;
        }
    }
    return NO;
}

- (void)enqueueDelayedSaveWithGroup:(ZMSDispatchGroup *)group;
{
    if(self.userInfo[IsSaveDisabled]) {
        return;
    }
    
    if ([self saveIfTooManyChanges] ||
        [self saveIfDelayIsTooLong])
    {
        return;
    }
    
    // Delay function (not to scale):
    //       ^
    //       │
    //  0.100│\
    //       │  \
    //       │    \
    //       │      \
    // delay │        \
    //       │          \
    //       │            \
    //  0.002│              +------------------
    //       │              :
    //       +———————————————————————————————————>
    //       0              1s
    //            time since last save
    
    const double delta_s = (self.timeOfLastSave != nil) ? (-[self.timeOfLastSave timeIntervalSinceNow]) : 10000;
    const double delay_s = (delta_s > 0.98) ? 0.002 : (-0.1*delta_s + 0.1);
    const unsigned int delay_ms = (unsigned int) lround(delay_s*1000);
    
    // Grab a unique number, for debugging only:
    static int32_t c;
    int32_t myCount = ++c;
    ZMTraceObjectContextEnqueueSave(2, myCount, (int) 0);
    ZMLogDebug(@"enqueueDelayedSaveWithGroup: called (%d)", myCount);
    
    // This code is a bit daunting at first. There are a total of 3 groups:
    //
    // otherGroups: This keeps track of "the context is doing some work" INCLUDING delayed save
    // secondaryGroup: This keeps track of "the context is doing some work" EXCLUDING delayed save
    // group: Passed in group
    //
    // (1) We'll enter all groups.
    //
    // (2) We increment the pendingSaveCounter
    //
    // (2) After a tiny time interval, we'll leave the secondary group. Since calls to -performGroupedBlock:
    //     also get added to this group, we can use
    //         dispatch_group_notify(secondaryGroup, ...)
    //     to know that no further work is scheduled on this context. At that point we decrement pendingSaveCounter.
    //
    // (3) If pendingSaveCounter is 0 at this point (no outstanding saves), we perform the actual save.
    //
    // The pendingSaveCounter ensures that only the last enqueued save will perform the actual save, ie. it's
    // safe and efficient to call this method multiple times.
    //
    //     work -> enqueueSave -> work -> enqueueSave -> work -> enqueueSave
    //                                                                      \--> save at this point
    //
    
    
    // Enter all groups:
    if (group) {
        [group enter];
    }
    ZMSDispatchGroup *secondaryGroup;
    NSArray *otherGroups;
    {
        NSArray *groups = [self enterAllGroups];
        secondaryGroup = groups[1];
        NSMutableIndexSet *otherIndexes = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, groups.count)];
        [otherIndexes removeIndex:1];
        otherGroups = [groups objectsAtIndexes:otherIndexes];
    }
    
    NSInteger const c1 = ++self.pendingSaveCounter;
    ZMTraceObjectContextEnqueueSave(3, myCount, (int) c1);
    
    // We'll wait just a little bit, just in case the group empties for a short span of time.
    {
        ZMLogDebug(@"dispatch_after() entered (%d)", myCount);
        dispatch_time_t when = dispatch_walltime(NULL, delay_ms * NSEC_PER_MSEC);
        dispatch_queue_t waitQueue = (ZMHasQualityOfServiceSupport() ?
                                      dispatch_get_global_queue(QOS_CLASS_UTILITY, 0) :
                                      dispatch_get_global_queue(0, 0));
        dispatch_after(when, waitQueue, ^{
            [secondaryGroup leave];
            ZMTraceObjectContextEnqueueSave(4, myCount, 0);
            ZMLogDebug(@"dispatch_after() completed (%d)", myCount);
        });
    }
    
    // Once the save group is empty (no pending saves), we'll do the actual save:
    [secondaryGroup notifyOnQueue:dispatch_get_global_queue(0, 0) block:^{
        ZMTraceObjectContextEnqueueSave(5, myCount, 0);
        [self performGroupedBlock:^{
            NSInteger const c2 = --self.pendingSaveCounter;
            ZMTraceObjectContextEnqueueSave(6, myCount, (int) c2);
            if (c2 == 0) {
                ZMLogDebug(@"Calling -saveOrRollback (%d)", myCount);
                [self saveOrRollback];
            } else {
                ZMLogDebug(@"Not calling -saveOrRollback (%d)", myCount);
            }
            if (group) {
                [group leave];
            }
            [self leaveAllGroups:otherGroups];
        }];
    }];
}

- (void)ensureSingletonsExist;
{
    static OSSpinLock lock = OS_SPINLOCK_INIT;
    [self performGroupedBlock:^{
        OSSpinLockLock(&lock);
        [ZMUser selfUserInContext:self];
        OSSpinLockUnlock(&lock);
    }];
}

- (NSMutableDictionary *)metadataInfo;
{
    NSMutableDictionary *metadataInfo = self.userInfo[MetadataKey];
    if (!metadataInfo) {
        metadataInfo = [NSMutableDictionary dictionary];
        self.userInfo[MetadataKey] = metadataInfo;
    }
    return metadataInfo;
}

- (void)makeMetadataPersistent;
{
    NSDictionary *metadata = self.userInfo[MetadataKey];
    if (nil != metadata) {
        NSMutableDictionary *newStoredMetadata = [[self.persistentStoreCoordinator metadataForPersistentStore:[self firstPersistentStore]] mutableCopy];
        
        [metadata enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop ZM_UNUSED)
        {
            if ([obj isKindOfClass:[NSNull class]]) {
                [newStoredMetadata removeObjectForKey:key];
            } else if (obj) {
                newStoredMetadata[key] = obj;
            }
        }];
        [self.persistentStoreCoordinator setMetadata:newStoredMetadata forPersistentStore:[self firstPersistentStore]];
        self.userInfo[MetadataKey] = nil;
    }
}

- (id)persistentStoreMetadataForKey:(NSString *)key;
{
    NSMutableDictionary *userInfoMetadata = [self metadataInfo];
    id result = userInfoMetadata[key];
    if (nil == result) {
        NSDictionary *storedMetadata = [self.persistentStoreCoordinator metadataForPersistentStore:[self firstPersistentStore]];
        result = storedMetadata[key];
    }
    if ([result isKindOfClass:[NSNull class]]) return nil;
    
    return result;
}

- (void)setPersistentStoreMetadata:(id)value forKey:(NSString *)key;
{
    VerifyReturn(key != nil);
    NSMutableDictionary *mutableMetadata = [self metadataInfo];
    if (value) {
        mutableMetadata[key] = value;
    } else {
        mutableMetadata[key] = [NSNull null];
    }
}

- (NSPersistentStore *)firstPersistentStore
{
    NSArray *stores = [self.persistentStoreCoordinator persistentStores];
    NSAssert(stores.count == 1, @"Invalid number of stores");
    NSPersistentStore *store = stores[0];
    return store;
}

+ (NSManagedObjectModel *)loadManagedObjectModel;
{
    // On iOS we can't put the model into the library. We need to load it from the test bundle.
    // On OS X, we'll load it from the zmessaging Framework.
    NSBundle *modelBundle = [NSBundle bundleForClass:[ZMManagedObject class]];
    NSManagedObjectModel *result = [NSManagedObjectModel mergedModelFromBundles:@[modelBundle]];
    NSAssert(result != nil, @"Unable to load zmessaging model.");
    return result;
}

- (NSArray *)executeFetchRequestOrAssert:(NSFetchRequest *)request;
{
    NSError *error;
    NSArray *result = [self executeFetchRequest:request error:&error];
    RequireString(result != nil, "Error in fetching: %lu", (long) error.code);
    return result;
}

- (void)continuouslyCheckForUnsavedChanges;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (! [[NSUserDefaults standardUserDefaults] boolForKey:@"ZMCheckForUnsavedChangesOnUIContext"]) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self checkForUnsavedChanges];
        });
    });
}

- (void)checkForUnsavedChanges;
{
    // When ZMCheckForUnsavedChangesOnUIContext is set to YES, this will log a warning when
    // the UI forgets to wrap changes inside a call to -performChanges:
    //
    // To use this, pass
    //     -ZMCheckForUnsavedChangesOnUIContext YES
    // as a launch argument.
    //
    if ([self hasChanges]) {
        ZMLogWarn(@"User Interface context is out of sync.");
        ZMLogWarn(@"Context <%@: %p> has unsaved changes:", self.class, self);
        ZMLogWarn(@"Please use -[ZMUserSession performChanges:].");
        for (NSManagedObject *mo in self.updatedObjects) {
            ZMLogWarn(@"    <%@: %p>: %@", mo.class, mo, [mo.changedValues.allKeys componentsJoinedByString:@", "]);
        }
        for (NSManagedObject *mo in self.insertedObjects) {
            ZMLogWarn(@"    <%@: %p> (inserted)", mo.class, mo);
        }
        __builtin_trap();
    }
    [self performSelector:_cmd withObject:nil afterDelay:0.5];
}

@end


static dispatch_queue_t singletonContextIsolation(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("moc.singletonContextIsolation", 0);
    });
    return queue;
}



@implementation NSManagedObjectContext (zmessagingTests)

- (void)enableForceRollback;
{
    self.userInfo[IsFailingToSave] = @YES;
}

- (void)disableForceRollback;
{
    [self.userInfo removeObjectForKey:IsFailingToSave];
}

- (void)disableSaves;
{
    self.userInfo[IsSaveDisabled] = @YES;
}

- (void)enableSaves;
{
    [self.userInfo removeObjectForKey:IsSaveDisabled];
}

- (void)markAsSyncContext;
{
    [self performBlockAndWait:^{
        self.userInfo[IsSyncContextKey] = @YES;
    }];
}

- (void)markAsSearchContext;
{
    [self performBlockAndWait:^{
        self.userInfo[IsSearchContextKey] = @YES;
    }];
}

- (void)markAsUIContext
{
    [self performBlockAndWait:^{
        self.userInfo[IsUserInterfaceContextKey] = @YES;
        self.displayNameGenerator = [[ZMUserDisplayNameGenerator alloc] initWithManagedObjectContext:self];
    }];
}

- (void)resetContextType
{
    [self performBlockAndWait:^{
        self.userInfo[IsSyncContextKey] = @NO;
        self.userInfo[IsUserInterfaceContextKey] = @NO;
        self.userInfo[IsSearchContextKey] = @NO;
    }];
}

- (void)disableObjectRefresh;
{
    self.userInfo[IsRefreshOfObjectsDisabled] = @YES;
}

@end



@implementation NSManagedObjectContext (CleanUp)

- (void)refreshUnneededObjects
{
    if(self.zm_shouldRefreshObjectsWithSyncContextPolicy) {
        [ZMConversation refreshObjectsThatAreNotNeededInSyncContext:self];
    }
    if(self.zm_shouldRefreshObjectsWithUIContextPolicy) {
        // TODO
    }
}


@end


static NSString * const UserImagesCacheKey = @"userImagesCache";

@implementation NSManagedObjectContext (UserImagesCache)

- (void)setUserImagesCache:(NSCache *)cache
{
    self.userInfo[UserImagesCacheKey] = cache;
}

- (NSCache *)userImagesCache
{
    return self.userInfo[UserImagesCacheKey];
}

- (NSData *)userImageForRemoteIdentifier:(NSUUID *)remoteId
{
    if (remoteId == nil) {
        return nil;
    }
    return [[self userImagesCache] objectForKey:remoteId.transportString];
}

- (void)storeUserImage:(NSData *)imageData forRemoteIdentifier:(NSUUID *)remoteId
{
    if (remoteId == nil) {
        return;
    }
    
    if (imageData == nil) {
        [[self userImagesCache] removeObjectForKey:remoteId.transportString];
    }
    else {
        [[self userImagesCache] setObject:imageData forKey:remoteId.transportString];
    }
}

@end

