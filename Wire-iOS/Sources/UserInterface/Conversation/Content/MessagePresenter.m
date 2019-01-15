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

#import "MessagePresenter.h"
#import "MessagePresenter+Internal.h"
#import "WireSyncEngine+iOS.h"
#import "Analytics.h"
#import "Wire-Swift.h"
#import "UIViewController+WR_Additions.h"

@import AVKit;
@import AVFoundation;

static NSString* ZMLogTag ZM_UNUSED = @"UI";


@interface MessagePresenter ()
@property (nonatomic, readwrite) BOOL waitingForFileDownload;
@end

@implementation MessagePresenter

- (void)openMessage:(id<ZMConversationMessage>)message targetView:(UIView *)targetView actionResponder:(nullable id<MessageActionResponder>)delegate
{
    self.waitingForFileDownload = NO;
    [self.modalTargetController.view.window endEditing:YES];

    if ([Message isLocationMessage:message]) {
        [self openLocationMessage:message];
    }
    else if ([Message isFileTransferMessage:message]) {
        if (message.fileMessageData.fileURL == nil) {
            self.waitingForFileDownload = YES;
            [[ZMUserSession sharedSession] performChanges:^{
                [message.fileMessageData requestFileDownload]; ///TODO: open file after file is downloaded
            }];
        }
        else {
            [self openFileMessage:message targetView:targetView];
        }
    }
    else if ([Message isImageMessage:message]) {
        [self openImageMessage:message actionResponder:delegate];
    }
    else if (message.textMessageData.linkPreview != nil) {
        [[message.textMessageData.linkPreview openableURL] open];
    }
}

- (void)openLocationMessage:(id<ZMConversationMessage>)message
{
    [Message openInMaps:message.locationMessageData];
}

- (void)cleanupTemporaryFileLink
{
    NSError *linkDeleteError = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.documentInteractionController.URL error:&linkDeleteError];
    if (linkDeleteError) {
        ZMLogError(@"Cannot delete temporary link %@: %@", self.documentInteractionController.URL, linkDeleteError);
    }
}

- (nullable UIViewController *)viewControllerForImageMessage:(id<ZMConversationMessage>)message
                                             actionResponder:(nullable id<MessageActionResponder>)delegate
{
    if (! [Message isImageMessage:message]) {
        return nil;
    }
    
    if (message.imageMessageData == nil) {
        return nil;
    }
    
    return [self imagesViewControllerFor:message actionResponder:delegate isPreviewing: NO];
}

- (nullable UIViewController *)viewControllerForImageMessagePreview:(id<ZMConversationMessage>)message
                                                    actionResponder:(nullable id<MessageActionResponder>)delegate

{
    if (! [Message isImageMessage:message]) {
        return nil;
    }

    if (message.imageMessageData == nil) {
        return nil;
    }

    return [self imagesViewControllerFor:message actionResponder:delegate isPreviewing:YES];
}

- (void)openImageMessage:(id<ZMConversationMessage>)message actionResponder:(nullable id<MessageActionResponder>)delegate
{
    UIViewController *imageViewController = [self viewControllerForImageMessage:message actionResponder:delegate];
    [self.modalTargetController presentViewController:imageViewController animated:YES completion:nil];
}

@end
