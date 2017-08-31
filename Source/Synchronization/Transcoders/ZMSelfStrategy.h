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
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


@import WireMessageStrategy;

@class NSManagedObjectContext;
@class NSOperationQueue;
@class ZMUpstreamModifiedObjectSync;
@class ZMClientRegistrationStatus;
@class ZMApplicationStatusDirectory;
@class SyncStatus;

@interface ZMSelfStrategy : ZMAbstractRequestStrategy <ZMContextChangeTrackerSource>

@property (nonatomic, readonly) BOOL isSelfUserComplete;

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)applicationStatus NS_UNAVAILABLE;

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
                           applicationStatus:(id<ZMApplicationStatus>)appplicationStatus
                    clientRegistrationStatus:(ZMClientRegistrationStatus *)clientRegistrationStatus
                                  syncStatus:(SyncStatus *)syncStatus;

- (void)tearDown;

@end


@interface ZMSelfStrategy (ContextChangeTracker) <ZMContextChangeTracker>
@end

