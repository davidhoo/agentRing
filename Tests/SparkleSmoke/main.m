#import <AppKit/AppKit.h>
#import <Sparkle/Sparkle.h>

// Only compiled by test-sparkle-update.sh, never embedded in Agent Ring.
// Drives a disposable sandboxed app through Sparkle's real installer and relaunch.
static void record(NSString *event) {
    NSLog(@"SMOKE %@", event);
    NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    [[NSFileManager defaultManager] createDirectoryAtURL:documents withIntermediateDirectories:YES attributes:nil error:nil];
    [event writeToURL:[documents URLByAppendingPathComponent:@"sparkle-smoke-result.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

@interface SmokeDelegate : NSObject <NSApplicationDelegate, SPUUserDriver, SPUUpdaterDelegate>
@property SPUUpdater *updater;
@end

@implementation SmokeDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if ([version isEqualToString:@"2.0.0"]) {
        record(@"PASS: installed and relaunched 2.0.0");
        [NSApp terminate:nil];
        return;
    }
    record(@"START: 1.0.0");
    self.updater = [[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle applicationBundle:NSBundle.mainBundle userDriver:self delegate:self];
    NSError *error = nil;
    if (![self.updater startUpdater:&error]) {
        record([NSString stringWithFormat:@"FAIL start: %@", error]);
        [NSApp terminate:nil];
        return;
    }
    [self.updater checkForUpdates];
}
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply {
    record(@"FAIL: unexpected permission request");
    [NSApp terminate:nil];
}
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancellation {}
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply {
    record(@"FOUND"); reply(SPUUserUpdateChoiceInstall);
}
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error {}
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement {
    record([NSString stringWithFormat:@"FAIL no update: %@", error]); acknowledgement(); [NSApp terminate:nil];
}
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))acknowledgement {
    record([NSString stringWithFormat:@"REJECTED: %@", error]); acknowledgement(); [NSApp terminate:nil];
}
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancellation { record(@"DOWNLOADING"); }
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate { record(@"EXTRACTING"); }
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply { record(@"INSTALLING"); reply(SPUUserUpdateChoiceInstall); }
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry {}
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))acknowledgement { acknowledgement(); }
- (void)dismissUpdateInstallation {}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        SmokeDelegate *delegate = [SmokeDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
