//
//  CHRChannelViewController.m
//  Chatroom
//
//  Created by Harshad on 26/12/13.
//  Copyright (c) 2013 Laughing Buddha Software. All rights reserved.
//

#import "CHRChannelViewController.h"
#import "CHRChannelView.h"

#import <MultipeerConnectivity/MultipeerConnectivity.h>

NSString *const CHRServiceName = @"CHR-chatroom";

@interface CHRChannelViewController () <MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate> {
    __weak CHRChannelView *_channelView;
    BOOL _shouldAttemptReconnection;
    UIBackgroundTaskIdentifier _discoveryBackgroundTask;
}

- (void)didFinishComposingMessage:(UITextField *)composeField;

@property (strong, nonatomic) MCPeerID *peerID;
@property (strong, nonatomic) MCSession *session;
@property (strong, nonatomic) MCNearbyServiceAdvertiser *serviceAdvertiser;
@property (strong, nonatomic) MCNearbyServiceBrowser *serviceBrowser;

@end

@implementation CHRChannelViewController

- (instancetype)initAsAdvertiser {
    self = [super init];
    if (self != nil) {

        MCPeerID *peerId = [[MCPeerID alloc] initWithDisplayName:@"Bender"];
        _peerID = peerId;

        MCSession *session = [[MCSession alloc] initWithPeer:_peerID];
        _session = session;
        [_session setDelegate:self];

        MCNearbyServiceAdvertiser *serviceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_peerID discoveryInfo:nil serviceType:CHRServiceName];
        _serviceAdvertiser = serviceAdvertiser;
        [_serviceAdvertiser setDelegate:self];
    }

    return self;
}

- (instancetype)initAsBrowser {

    self = [super init];
    if (self != nil) {

        MCPeerID *peerId = [[MCPeerID alloc] initWithDisplayName:@"Zoidberg"];
        _peerID = peerId;

        MCSession *session = [[MCSession alloc] initWithPeer:_peerID];
        _session = session;
        [_session setDelegate:self];

        MCNearbyServiceBrowser *serviceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:_peerID serviceType:CHRServiceName];
        _serviceBrowser = serviceBrowser;
        [_serviceBrowser setDelegate:self];

    }

    return self;

}

- (void)loadView {
    CHRChannelView *channelView = [[CHRChannelView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [channelView setAutoresizingMask:(UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth)];
    [self setView:channelView];

    _channelView = channelView;

}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    [[_channelView composeField] addTarget:self action:@selector(didFinishComposingMessage:) forControlEvents:UIControlEventEditingDidEndOnExit];
    [[_channelView composeField] setReturnKeyType:UIReturnKeySend];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)refresh {
    if (self.serviceAdvertiser != nil) {
        [self.serviceAdvertiser startAdvertisingPeer];
    }
    
    if (self.serviceBrowser != nil) {

        [self.serviceBrowser startBrowsingForPeers];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self refresh];
}

#pragma mark - Actions

- (void)didFinishComposingMessage:(UITextField *)composeField {
    [self sendDataToAllPeers:[self payloadWithMessage:composeField.text]];
    [[_channelView messagesView] setText:[NSString stringWithFormat:@"%@\nYou: %@", [[_channelView messagesView] text], composeField.text]];
    [composeField setText:nil];
}

#pragma mark - Private methods

- (NSData *)payloadWithMessage:(NSString *)message {
    NSString *payloadString = [NSString stringWithFormat:@"%@: %@", [_peerID displayName], message];
    return [payloadString dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)sendDataToAllPeers:(NSData *)data {
    NSError *error = nil;
    [_session sendData:data toPeers:[_session connectedPeers] withMode:MCSessionSendDataUnreliable error:&error];

    if (error != nil) {
        NSLog(@"%@", [error localizedDescription]);
    }
}

#pragma mark - MCSesionDelegate methods

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    [localNotification setFireDate:[NSDate date]];
    [localNotification setAlertBody:@"Received message"];
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *displayText = [[_channelView messagesView] text];
        displayText = [displayText stringByAppendingFormat:@"\n%@", message];
        [[_channelView messagesView] setText:displayText];
    });

}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)stopServices {
    if (_serviceBrowser != nil) {
        [_serviceBrowser stopBrowsingForPeers];
    } else {
        [_serviceAdvertiser stopAdvertisingPeer];
    }


}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (state == MCSessionStateConnected) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _shouldAttemptReconnection = NO;
            NSString *statusUpdate = [NSString stringWithFormat:@"%@\n*** %@ has joined the channel", [[_channelView messagesView] text], [peerID displayName]];
            [[_channelView messagesView] setText:statusUpdate];
            [self stopServices];
        });
    } else if (state == MCSessionStateNotConnected) {
        _shouldAttemptReconnection = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *statusUpdate = [NSString stringWithFormat:@"%@\n*** %@ has left the channel", [[_channelView messagesView] text], [peerID displayName]];
            [[_channelView messagesView] setText:statusUpdate];

            [self refresh];
        });
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - MCNearbyServiceAdvertiserDelegate methods

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    [localNotification setAlertBody:[NSString stringWithFormat:@"%@ wants to connect", [peerID displayName]]];
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];

    invitationHandler(YES, _session);
}

#pragma mark - MCNearbyServiceBrowserDelegate methods

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    [_serviceBrowser invitePeer:peerID toSession:_session withContext:nil timeout:150];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    _shouldAttemptReconnection = YES;
    [self refresh];
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)didEnterBackground:(NSNotification *)notification {
    if (_discoveryBackgroundTask == UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:_discoveryBackgroundTask];
        _discoveryBackgroundTask = UIBackgroundTaskInvalid;
    }

    [self stopServices];

    _discoveryBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self stopServices];
        [[UIApplication sharedApplication] endBackgroundTask:_discoveryBackgroundTask];
        _discoveryBackgroundTask = UIBackgroundTaskInvalid;
    }];
    if (_shouldAttemptReconnection) {
        [self refresh];
    }

}

- (void)didEnterForeground:(NSNotification *)notification {

    if (_discoveryBackgroundTask == UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:_discoveryBackgroundTask];
        _discoveryBackgroundTask = UIBackgroundTaskInvalid;
    }

    if (_shouldAttemptReconnection) {
        [self refresh];
    }


}



@end
