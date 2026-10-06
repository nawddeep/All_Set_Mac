// Now Playing bridge that runs inside /usr/bin/perl.
//
// Since macOS 15.4, MediaRemote only returns Now Playing info to Apple-signed
// processes. /usr/bin/perl is one, and it doesn't enforce library validation, so
// MediaController launches perl with a tiny loader script that dlopens this
// library and calls allset_media_run(). From then on the helper:
//   - writes one JSON object per line to stdout whenever playback changes
//   - reads newline-separated commands from stdin: toggle, play, pause, next,
//     previous, seek <seconds>, refresh
//   - exits when stdin closes, i.e. when the app quits or crashes.

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <errno.h>
#include <math.h>
#include <unistd.h>
#include "MediaHelper.h"

#if !__has_feature(objc_arc)
#error "MediaHelper.m must be compiled with ARC"
#endif

typedef void (*MRGetNowPlayingInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRGetClientFn)(dispatch_queue_t, void (^)(id));
typedef CFStringRef (*MRClientStringFn)(id);
typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef Boolean (*MRSendCommandFn)(int, CFDictionaryRef);
typedef void (*MRSetElapsedTimeFn)(double);

// MRMediaRemoteCommand values.
enum {
    MRCommandPlay = 0,
    MRCommandPause = 1,
    MRCommandTogglePlayPause = 2,
    MRCommandNextTrack = 4,
    MRCommandPreviousTrack = 5,
};

// Exit status that tells MediaController not to relaunch the helper.
static const int ExitUnavailable = 2;

static MRGetNowPlayingInfoFn MRGetNowPlayingInfo;
static MRGetIsPlayingFn MRGetIsPlaying;
static MRGetClientFn MRGetClient;
static MRClientStringFn MRClientBundleIdentifier;
static MRClientStringFn MRClientParentBundleIdentifier;
static MRSendCommandFn MRSendCommand;
static MRSetElapsedTimeFn MRSetElapsedTime;

static NSString *lastArtworkID;
static NSDictionary *lastMessage;
static BOOL refreshPending;

static void writeLine(NSDictionary *object) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    if (json == nil) return;
    NSMutableData *line = [json mutableCopy];
    [line appendBytes:"\n" length:1];
    const uint8_t *bytes = line.bytes;
    size_t remaining = line.length;
    while (remaining > 0) {
        ssize_t written = write(STDOUT_FILENO, bytes, remaining);
        if (written < 0) {
            if (errno == EINTR) continue;
            exit(0); // The app closed its end of the pipe.
        }
        bytes += written;
        remaining -= (size_t)written;
    }
}

// FNV-1a. Only used to tell artworks apart when MediaRemote gives no identifier.
static NSString *hashData(NSData *data) {
    uint64_t hash = 0xcbf29ce484222325ULL;
    const uint8_t *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        hash ^= bytes[i];
        hash *= 0x100000001b3ULL;
    }
    return [NSString stringWithFormat:@"%016llx", hash];
}

static void emit(BOOL isPlaying, NSString *bundleID, NSString *parentBundleID, NSDictionary *info) {
    NSMutableDictionary *message = [@{ @"type": @"nowPlaying", @"isPlaying": @(isPlaying) } mutableCopy];
    NSString *artworkBase64 = nil;

    if (info.count == 0) {
        lastArtworkID = nil;
        message[@"hasInfo"] = @NO;
    } else {
        message[@"hasInfo"] = @YES;
        if (bundleID.length) message[@"bundleIdentifier"] = bundleID;
        if (parentBundleID.length) message[@"parentBundleIdentifier"] = parentBundleID;

        NSDictionary<NSString *, NSString *> *strings = @{
            @"title": @"kMRMediaRemoteNowPlayingInfoTitle",
            @"artist": @"kMRMediaRemoteNowPlayingInfoArtist",
            @"album": @"kMRMediaRemoteNowPlayingInfoAlbum",
        };
        [strings enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *infoKey, BOOL *stop) {
            id value = info[infoKey];
            if ([value isKindOfClass:[NSString class]]) message[key] = value;
        }];

        NSDictionary<NSString *, NSString *> *numbers = @{
            @"duration": @"kMRMediaRemoteNowPlayingInfoDuration",
            @"elapsedTime": @"kMRMediaRemoteNowPlayingInfoElapsedTime",
            @"playbackRate": @"kMRMediaRemoteNowPlayingInfoPlaybackRate",
        };
        [numbers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *infoKey, BOOL *stop) {
            id value = info[infoKey];
            // NSJSONSerialization throws on NaN and infinity (live streams).
            if ([value isKindOfClass:[NSNumber class]] && isfinite([value doubleValue])) message[key] = value;
        }];

        id timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
        if ([timestamp isKindOfClass:[NSDate class]]) message[@"timestamp"] = @([timestamp timeIntervalSince1970]);

        id artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
        if ([artwork isKindOfClass:[NSData class]] && [artwork length] > 0) {
            id identifier = info[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"];
            NSString *artworkID = [identifier isKindOfClass:[NSString class]] ? identifier : hashData(artwork);
            message[@"artworkID"] = artworkID;
            if (![artworkID isEqualToString:lastArtworkID]) {
                artworkBase64 = [artwork base64EncodedStringWithOptions:0];
                lastArtworkID = artworkID;
            }
        } else {
            lastArtworkID = nil;
        }
    }

    // The periodic refresh usually finds nothing new; don't wake the app for it.
    if (artworkBase64 == nil && [message isEqualToDictionary:lastMessage]) return;
    lastMessage = [message copy];
    if (artworkBase64 != nil) message[@"artwork"] = artworkBase64;
    writeLine(message);
}

static void refresh(void) {
    dispatch_queue_t main = dispatch_get_main_queue();
    MRGetIsPlaying(main, ^(Boolean isPlaying) {
        void (^withClient)(id) = ^(id client) {
            NSString *bundleID = nil;
            NSString *parentBundleID = nil;
            if (client != nil && MRClientBundleIdentifier != NULL) {
                bundleID = [(__bridge NSString *)MRClientBundleIdentifier(client) copy];
            }
            if (client != nil && MRClientParentBundleIdentifier != NULL) {
                parentBundleID = [(__bridge NSString *)MRClientParentBundleIdentifier(client) copy];
            }
            MRGetNowPlayingInfo(main, ^(CFDictionaryRef info) {
                emit(isPlaying, bundleID, parentBundleID, (__bridge NSDictionary *)info);
            });
        };
        if (MRGetClient != NULL) {
            MRGetClient(main, withClient);
        } else {
            withClient(nil);
        }
    });
}

// Coalesces bursts of notifications (a track change posts several) into one read.
static void scheduleRefresh(double delay) {
    if (refreshPending) return;
    refreshPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        refreshPending = NO;
        refresh();
    });
}

static void handleCommand(NSString *line) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@" "];
    NSString *command = parts.firstObject;
    if ([command isEqualToString:@"toggle"]) {
        MRSendCommand(MRCommandTogglePlayPause, NULL);
    } else if ([command isEqualToString:@"play"]) {
        MRSendCommand(MRCommandPlay, NULL);
    } else if ([command isEqualToString:@"pause"]) {
        MRSendCommand(MRCommandPause, NULL);
    } else if ([command isEqualToString:@"next"]) {
        MRSendCommand(MRCommandNextTrack, NULL);
    } else if ([command isEqualToString:@"previous"]) {
        MRSendCommand(MRCommandPreviousTrack, NULL);
    } else if ([command isEqualToString:@"seek"] && parts.count > 1 && MRSetElapsedTime != NULL) {
        MRSetElapsedTime(parts[1].doubleValue);
    } else if (![command isEqualToString:@"refresh"]) {
        return;
    }
    scheduleRefresh(0.2);
}

static void readCommands(void) {
    static dispatch_source_t source;
    static NSMutableData *pending;
    pending = [NSMutableData data];
    NSData *newline = [NSData dataWithBytes:"\n" length:1];

    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(source, ^{
        uint8_t chunk[4096];
        ssize_t count = read(STDIN_FILENO, chunk, sizeof chunk);
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) return;
        if (count <= 0) exit(0); // stdin closed: the app is gone.

        [pending appendBytes:chunk length:(NSUInteger)count];
        while (YES) {
            NSRange range = [pending rangeOfData:newline options:0 range:NSMakeRange(0, pending.length)];
            if (range.location == NSNotFound) break;
            NSData *lineData = [pending subdataWithRange:NSMakeRange(0, range.location)];
            [pending replaceBytesInRange:NSMakeRange(0, range.location + 1) withBytes:NULL length:0];
            NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
            if (line.length > 0) handleCommand(line);
        }
    });
    dispatch_resume(source);
}

static NSString *notificationName(void *framework, const char *symbol) {
    CFStringRef *name = dlsym(framework, symbol);
    return (name != NULL && *name != NULL) ? (__bridge NSString *)*name : @(symbol);
}

static void fail(NSString *message) {
    writeLine(@{ @"type": @"error", @"message": message });
    exit(ExitUnavailable);
}

void allset_media_run(void *perlInterpreter, void *cv) {
    (void)perlInterpreter;
    (void)cv;

    void *framework = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    if (framework == NULL) fail(@"MediaRemote.framework could not be loaded");

    MRGetNowPlayingInfo = (MRGetNowPlayingInfoFn)dlsym(framework, "MRMediaRemoteGetNowPlayingInfo");
    MRGetIsPlaying = (MRGetIsPlayingFn)dlsym(framework, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    MRGetClient = (MRGetClientFn)dlsym(framework, "MRMediaRemoteGetNowPlayingClient");
    MRClientBundleIdentifier = (MRClientStringFn)dlsym(framework, "MRNowPlayingClientGetBundleIdentifier");
    MRClientParentBundleIdentifier = (MRClientStringFn)dlsym(framework, "MRNowPlayingClientGetParentAppBundleIdentifier");
    MRSendCommand = (MRSendCommandFn)dlsym(framework, "MRMediaRemoteSendCommand");
    MRSetElapsedTime = (MRSetElapsedTimeFn)dlsym(framework, "MRMediaRemoteSetElapsedTime");
    MRRegisterFn registerForNotifications = (MRRegisterFn)dlsym(framework, "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (!MRGetNowPlayingInfo || !MRGetIsPlaying || !MRSendCommand || !registerForNotifications) {
        fail(@"MediaRemote is missing functions this helper needs");
    }

    registerForNotifications(dispatch_get_main_queue());
    const char *names[] = {
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
    };
    for (size_t i = 0; i < sizeof names / sizeof names[0]; i++) {
        [[NSNotificationCenter defaultCenter] addObserverForName:notificationName(framework, names[i])
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) { scheduleRefresh(0.05); }];
    }

    readCommands();
    writeLine(@{ @"type": @"ready" });
    refresh();

    // Not every player posts a notification for every change, so poll slowly too.
    static dispatch_source_t timer;
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), 10 * NSEC_PER_SEC, NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{ scheduleRefresh(0); });
    dispatch_resume(timer);

    CFRunLoopRun();
    exit(0);
}
