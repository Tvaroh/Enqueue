#import "PRMainWindowController.h"
#import "NSWindow+Extensions.h"
#import "PRBrowserViewController.h"
#import "PRControlsViewController.h"
#import "PRCore.h"
#import "PRDb.h"
#import "PRDefaults.h"
#import "PRGradientView.h"
#import "PRHistoryViewController.h"
#import "PRLibraryViewController.h"
#import "PRMainMenuController.h"
#import "PRMainWindowView.h"
#import "PRNowPlayingController.h"
#import "PRNowPlayingViewController.h"
#import "PRPlaylists.h"
#import "PRPlaylistsViewController.h"
#import "PRPreferencesViewController.h"
#import "PRToolbarController.h"
#import <Quartz/Quartz.h>

@interface PRMainWindowController () <NSWindowDelegate, NSMenuDelegate, NSSplitViewDelegate>
@end

@implementation PRMainWindowController {
    __weak PRCore *_core;
    __weak PRDb *_db;
    
    PRToolbarController *_toolbarController;    
    PRMainMenuController *_mainMenuController;
    PRLibraryViewController *_libraryViewController; 
    PRHistoryViewController *_historyViewController;
    PRPlaylistsViewController *_playlistsViewController;
    PRPreferencesViewController *_preferencesViewController; 
    PRNowPlayingViewController *_nowPlayingViewController;
    PRControlsViewController *_controlsViewController;
    
    PRWindowMode _currentMode;
    id _currentViewController;
    
    BOOL _resizingSplitView;
    BOOL _windowWillResize;
}

#pragma mark - Initialization

- (id)initWithCore:(PRCore *)core {
    if ((self = [super initWithWindow:nil])) {
        _core = core;
        _db = [core db];
        _currentMode = PRWindowModeLibrary;

        _toolbarController = [[PRToolbarController alloc] init];
        _mainMenuController = [[PRMainMenuController alloc] initWithCore:_core]; 
        _libraryViewController = [[PRLibraryViewController alloc] initWithBridge:[_core bridge]];
        _preferencesViewController = [[PRPreferencesViewController alloc] initWithCore:_core];
        _playlistsViewController = [[PRPlaylistsViewController alloc] initWithCore:_core];
        _historyViewController = [[PRHistoryViewController alloc] initWithDb:_db mainWindowController:self];
        _nowPlayingViewController = [[PRNowPlayingViewController alloc] initWithCore:_core];    
        _controlsViewController = [[PRControlsViewController alloc] initWithCore:_core];
        // [nowPlayingSuperview addSubview:[_controlsViewController albumArtView]];
        
        NSUInteger styleMask = NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask;
        NSWindow *window = [[NSWindow alloc] initWithContentRect:CGRectMake(0, 0, 1000, 1000) styleMask:styleMask backing:NSBackingStoreBuffered defer:YES];
        [window setDelegate:self];
        [window setTitleVisibility:NSWindowTitleHidden];
        [window setToolbar:[_toolbarController toolbar]];
        [window setContentView:[[PRMainWindowView alloc] init]];
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
            [[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
        }
        [self setWindow:window];
        
        [self _reloadWindow];
        
        [window setInitialFirstResponder:[_libraryViewController firstKeyView]];
        [[_libraryViewController lastKeyView] setNextKeyView:[_nowPlayingViewController firstKeyView]];
        [[_nowPlayingViewController lastKeyView] setNextKeyView:[_libraryViewController firstKeyView]];
        
        // if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        //     [NSNotificationCenter addObserver:self selector:@selector(windowWillEnterFullScreen:) name:NSWindowWillEnterFullScreenNotification object:[self window]];
        //     [NSNotificationCenter addObserver:self selector:@selector(windowWillExitFullScreen:) name:NSWindowWillExitFullScreenNotification object:[self window]];
        // }
    }
    return self;
}

- (void)_reloadWindow {
    _currentViewController = _libraryViewController;
    
    PRMainWindowView *view = [[self window] contentView];
    [view setLeftViewController:_nowPlayingViewController];
    [view setCenterViewController:_libraryViewController];
    [view setBottomView:[_controlsViewController view]];
    [_libraryViewController setCurrentList:[[[_core db] playlists] libraryList]];
}

#pragma mark - Accessors

@synthesize mainMenuController = _mainMenuController; 
@synthesize libraryViewController = _libraryViewController;
@synthesize historyViewController = _historyViewController;
@synthesize playlistsViewController = _playlistsViewController;
@synthesize preferencesViewController = _preferencesViewController;
@synthesize nowPlayingViewController = _nowPlayingViewController;
@synthesize controlsViewController = _controlsViewController;

- (PRWindowMode)currentMode {
    return _currentMode;
}

- (void)setCurrentMode:(PRWindowMode)mode {
    _currentMode = mode;
    id newViewController;
    switch (_currentMode) {
        case PRWindowModeLibrary:
            newViewController = _libraryViewController;
            break;
        case PRWindowModePlaylists:
            newViewController = _playlistsViewController;
            break;
        case PRWindowModeHistory:
            newViewController = _historyViewController;
            [_historyViewController update];
            break;
        case PRWindowModePreferences:
            newViewController = _preferencesViewController;
            break;
        default:
            [PRException raise:NSInternalInconsistencyException format:@"Invalid Mode"];return;
            break;
    }
    _currentViewController = newViewController;
    [self updateUI];
}

- (BOOL)showsArtwork {
    return [[PRDefaults sharedDefaults] boolForKey:PRDefaultsShowArtwork];
}

- (void)setShowsArtwork:(BOOL)showsArtwork {
    [[PRDefaults sharedDefaults] setBool:showsArtwork forKey:PRDefaultsShowArtwork];
    [self updateSplitView];
}

- (BOOL)miniPlayer {
    return [[PRDefaults sharedDefaults] boolForKey:PRDefaultsMiniPlayer];
}

- (void)setMiniPlayer:(BOOL)miniPlayer {
    [[PRDefaults sharedDefaults] setBool:miniPlayer forKey:PRDefaultsMiniPlayer];
    
    NSRect winFrame;
    if ([self miniPlayer]) {
        winFrame = [[PRDefaults sharedDefaults] rectForKey:PRDefaultsMiniPlayerFrame];
        if (NSEqualRects(winFrame, NSZeroRect)) {
            winFrame.origin.x = [[self window] frame].origin.x;
            winFrame.origin.y = [[self window] frame].origin.y;
            winFrame.size.height = 500;
        }
        if (winFrame.size.height < 400 && winFrame.size.height != 140) {
            winFrame.size.height = 400;
        }
        winFrame.size.width = 215;        
    } else {
        winFrame = [[PRDefaults sharedDefaults] rectForKey:PRDefaultsPlayerFrame];
        if (NSEqualRects(winFrame, NSZeroRect)) {
            winFrame.origin.x = [[self window] frame].origin.x;
            winFrame.origin.y = [[self window] frame].origin.y;
            winFrame.size.height = 700;
            winFrame.size.width = 1000;
        }
        if (winFrame.size.height < 500) {
            winFrame.size.height = 500;
        }
        if (winFrame.size.width < 700+185) {
            winFrame.size.width = 700+185;
        }
    }
    [self updateLayoutWithFrame:winFrame];
}

- (void)toggleMiniPlayer {
    [self setMiniPlayer:![self miniPlayer]];
}

#pragma mark - UI

- (void)updateLayoutWithFrame:(NSRect)winFrame {
    // [[self window] setDelegate:nil];
    // [_splitView setDelegate:nil];
        
    // for (id i in @[libraryButton,playlistsButton, historyButton, preferencesButton]) {
    //     [i setHidden:[self miniPlayer]];
    // }
    // [_sidebarHeaderView setHidden:([self miniPlayer] && winFrame.size.height == 140)];
    // [_toolbarSubview setHidden:[self miniPlayer]];
    // [_headerView setHidden:[self miniPlayer]];
    
    // if ([self miniPlayer] && winFrame.size.height != 140) {
    //     // FULLSCREEN
    //     if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6 && [[self window] collectionBehavior] & NSWindowCollectionBehaviorFullScreenPrimary) {
    //         [[self window] setCollectionBehavior:[[self window] collectionBehavior] ^ NSWindowCollectionBehaviorFullScreenPrimary];
    //     }
        
    //     NSRect frame;
    //     // CONTROLS
    //     frame.origin.x = 0;
    //     frame.origin.y = 0;
    //     frame.size.height = 125;
    //     frame.size.width = winFrame.size.width;
    //     [controlsSuperview setFrame:frame];
    //     [controlsSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
    //     [_controlsViewController updateLayout];
        
    //     // SPLIT VIEW
    //     [_splitView removeFromSuperview];
        
    //     // NOW PLAYING
    //     [nowPlayingSuperview removeFromSuperview];
    //     [[[self window] contentView] addSubview:nowPlayingSuperview];
    //     frame.origin.x = 0;
    //     frame.origin.y = 125; 
    //     frame.size.height = winFrame.size.height - 30 - frame.origin.y;
    //     frame.size.width = winFrame.size.width;
    //     [nowPlayingSuperview setFrame:frame];
    //     [nowPlayingSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
        
    //     // CENTER
    //     [centerSuperview removeFromSuperview];
        
    //     // WINDOW
    //     [[self window] setFrame:winFrame display:YES animate:NO];
    //     [[self window] setMinSize:NSMakeSize(215, 140)]; // min 140 / 400
    //     [[self window] setMaxSize:NSMakeSize(215, 10000)];
    //     [controlsSuperview setAutoresizingMask:NSViewMaxYMargin|NSViewWidthSizable];
    //     [nowPlayingSuperview setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    // } else if ([self miniPlayer]) {
    //     // FULLSCREEN
    //     if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6 && [[self window] collectionBehavior] & NSWindowCollectionBehaviorFullScreenPrimary) {
    //         [[self window] setCollectionBehavior:[[self window] collectionBehavior] ^ NSWindowCollectionBehaviorFullScreenPrimary];
    //     }
        
    //     NSRect frame;
    //     // CONTROLS
    //     frame.origin.x = 0;
    //     frame.origin.y = 0;
    //     frame.size.height = 125;
    //     frame.size.width = winFrame.size.width;
    //     [controlsSuperview setFrame:frame];
    //     [controlsSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
    //     [_controlsViewController updateLayout];
        
    //     // SPLIT VIEW
    //     [_splitView removeFromSuperview];
        
    //     // NOW PLAYING
    //     [nowPlayingSuperview removeFromSuperview];
        
    //     // CENTER
    //     [centerSuperview removeFromSuperview];
        
    //     // WINDOW
    //     [[self window] setFrame:winFrame display:YES animate:NO];
    //     [[self window] setMinSize:NSMakeSize(215, 140)]; // min 140 / 400
    //     [[self window] setMaxSize:NSMakeSize(215, 10000)];
    //     [controlsSuperview setAutoresizingMask:NSViewMaxYMargin|NSViewWidthSizable];
    // } else {
    //     // FULLSCREEN
    //     if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
    //         [[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
    //     }
        
    //     NSRect frame;
    //     // CONTROLS
    //     frame.origin.x = 0;
    //     frame.origin.y = 0;
    //     frame.size.height = 54;
    //     frame.size.width = winFrame.size.width;
    //     [controlsSuperview setFrame:frame];
    //     [controlsSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
    //     [_controlsViewController updateLayout];
        
    //     // SPLIT VIEW
    //     [[[self window] contentView] addSubview:_splitView];
    //     frame.origin.x = 0;
    //     frame.origin.y = 54;
    //     frame.size.height = winFrame.size.height - 30 - 54;
    //     frame.size.width = winFrame.size.width;
    //     [_splitView setFrame:frame];
    //     [_splitView setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
        
    //     // NOW PLAYING
    //     [nowPlayingSuperview removeFromSuperview];
    //     [_splitView addSubview:nowPlayingSuperview];
        
    //     // CENTER
    //     [centerSuperview removeFromSuperview];
    //     [_splitView addSubview:centerSuperview];
        
    //     [_splitView setPosition:[[PRDefaults sharedDefaults] floatForKey:PRDefaultsSidebarWidth] ofDividerAtIndex:0];
        
    //     // WINDOW
    //     [[self window] setMinSize:NSMakeSize(700+185, 500)];
    //     [[self window] setMaxSize:NSMakeSize(10000, 10000)];
    //     [[self window] setFrame:winFrame display:YES animate:NO];
    //     [controlsSuperview setAutoresizingMask:NSViewMaxYMargin|NSViewWidthSizable];
    //     [_splitView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    //     [nowPlayingSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewHeightSizable];
    //     [centerSuperview setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    // }
    
    // [self updateSplitView];
    // [self updateUI];
    // [self updateWindowButtons];
    
    // [[self window] setDelegate:self];
    // [_splitView setDelegate:self];
}

- (void)updateSplitView {
    // NSRect frame;
    // frame = [_toolbarSubview frame];
    // frame.origin.x = [nowPlayingSuperview frame].size.width - 6;
    // frame.size.width = [[self window] frame].size.width - [nowPlayingSuperview frame].size.width + 54;
    // [_toolbarSubview setFrame:frame];
    
    // frame = [_sidebarHeaderView frame];
    // frame.origin.x = [nowPlayingSuperview frame].size.width - 53;
    // frame.size.width = [[self window] frame].size.width - [nowPlayingSuperview frame].size.width + 54;
    // [_sidebarHeaderView setFrame:frame];
    
    // if (![self miniPlayer] && ([[self window] frame].size.width - [nowPlayingSuperview frame].size.width < 700)) {
    //     [_splitView setPosition:[[self window] frame].size.width-700 ofDividerAtIndex:0];
    // }
    
    // if (![self miniPlayer]) {
    //     [[_controlsViewController albumArtView] setHidden:![self showsArtwork]];
    //     if ([self showsArtwork]) {
    //         // size of nowPlayingView
    //         frame = [nowPlayingSuperview bounds];
    //         frame.size.height -= [nowPlayingSuperview frame].size.width;
    //         if (frame.size.height < 220) {
    //             frame.size.height = 220;
    //         } 
    //         if ([nowPlayingSuperview frame].size.height - frame.size.height > 500) {
    //             frame.size.height = [nowPlayingSuperview frame].size.height - 500;
    //         }
    //         frame.origin.y = [nowPlayingSuperview frame].size.height - frame.size.height;
    //         [[_nowPlayingViewController view] setFrame:frame];
            
    //         // size of albumArt
    //         frame.origin.x = -1;
    //         frame.origin.y = -2;
    //         frame.size.width = [nowPlayingSuperview frame].size.width + 2;
    //         frame.size.height = [nowPlayingSuperview frame].size.height - [[_nowPlayingViewController view] frame].size.height + 2;
    //         [[_controlsViewController albumArtView] setFrame:frame];
    //     } else {
    //         frame = [nowPlayingSuperview bounds];
    //         [[_nowPlayingViewController view] setFrame:frame];
    //     }
    // } else {
    //     [[_controlsViewController albumArtView] setHidden:YES];
        
    //     // size of nowPlayingView
    //     frame = [nowPlayingSuperview bounds];
    //     [[_nowPlayingViewController view] setFrame:frame];
    // }
}

- (void)updateUI {
    // // Header buttons
    // NSButton *button;
    // switch (_currentMode) {
    //     case PRWindowModeLibrary:
    //         if ([[_libraryViewController currentList] isEqual:[[_db playlists] libraryList]]) {
    //             button = libraryButton;
    //         } else {
    //             button = playlistsButton;
    //         }
    //         break;
    //     case PRWindowModePlaylists:
    //         button = playlistsButton;
    //         break;
    //     case PRWindowModeHistory:
    //         button = historyButton;
    //         break;
    //     case PRWindowModePreferences:
    //         button = preferencesButton;
    //         break;
    //     default:
    //         button = libraryButton;
    //         break;
    // }
    // for (NSButton *i in @[libraryButton,playlistsButton,historyButton,preferencesButton]) {
    //     [i setState:NSOffState];
    // }
    // [button setState:NSOnState];
    
    // // Library view mode buttons
    // [_headerView setHidden:!(![self miniPlayer] && _currentMode == PRWindowModeLibrary)];
}

- (void)updateWindowButtons {
    // // Window Buttons
    // if ([self miniPlayer] && [[self window] frame].size.height == 140) {
        
    // } else {
    //     float x = 10;
    //     for (NSButton *i in @[[[self window] standardWindowButton:NSWindowCloseButton],
    //          [[self window] standardWindowButton:NSWindowMiniaturizeButton],
    //          [[self window] standardWindowButton:NSWindowZoomButton]]) {
    //         NSRect frame = [i frame];
    //         frame.origin.y = [[self window] frame].size.height - [i bounds].size.height - 7;
    //         frame.origin.x = x;
    //         [i setFrame:frame];
    //         x += 20;
    //     }
    // }
    // if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
    //     NSButton *fullScreen = [[self window] standardWindowButton:NSWindowFullScreenButton];
    //     NSRect frame = [fullScreen frame];
    //     frame.origin.y = [[self window] frame].size.height - [fullScreen bounds].size.height - 6;
    //     frame.origin.x = [[self window] frame].size.width - [fullScreen bounds].size.width - 9;
    //     [fullScreen setFrame:frame];
    // }
}

#pragma mark - Update Priv

- (void)headerButtonAction:(id)sender {
    if ([sender tag] == PRWindowModeLibrary) {
        [_libraryViewController setCurrentList:[[_db playlists] libraryList]];
    }
    [self setCurrentMode:[sender tag]];
}

#pragma mark - NSWindowDelegate

// - (void)windowWillEnterFullScreen:(NSNotification *)notification {
//     NSRect frame = [_splitView frame];
//     frame.size.height = [[self window] frame].size.height - 30 - 54 - 22;
//     [_splitView setFrame:frame];
// }

// - (void)windowWillExitFullScreen:(NSNotification *)notification {
//     _resizingSplitView = YES;
// //    [_splitView setDelegate:nil];
//     NSRect frame = [_splitView frame];
//     frame.size.height = [[self window] frame].size.height - 30 - 54 + 22;
//     [_splitView setFrame:frame];
    
//     if ([[PRDefaults sharedDefaults] rectForKey:PRDefaultsPlayerFrame].size.width - [nowPlayingSuperview frame].size.width < 700) {
//         [_splitView setPosition:[[PRDefaults sharedDefaults] rectForKey:PRDefaultsPlayerFrame].size.width - 700 ofDividerAtIndex:0];
//     }
// }

// - (void)windowDidExitFullScreen:(NSNotification *)notification {
//     if ([self window].frame.size.width - [nowPlayingSuperview frame].size.width < 700) {
//         [_splitView setPosition:[self window].frame.size.width-700 ofDividerAtIndex:0];
//     } else if ([nowPlayingSuperview frame].size.width < 185) {
//         [_splitView setPosition:185 ofDividerAtIndex:0];
//     }
//     [self updateSplitView];
// //    [_splitView setDelegate:self];
//     _resizingSplitView = NO;
// }

// - (BOOL)windowShouldClose:(id)sender {
//     if (sender == [self window]) {
//         [[self window] orderOut:self];
//         [NSApp addWindowsItem:[self window] title:@"Enqueue" filename:NO];
//         return NO;
//     }
//     return YES;
// }

// - (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {
//     if ([self miniPlayer] && [[self window] frame].size.height == 140) {
//         rect.origin.y -= 1;
//         return rect;
//     }
//     rect.origin.y -= 8;
//     return rect;
// }

// - (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
//     if (![self miniPlayer] && (frameSize.width - [nowPlayingSuperview frame].size.width < 700)) {
//         [_splitView setPosition:frameSize.width-700 ofDividerAtIndex:0];
//     } else if ([self miniPlayer]) {
//         if (frameSize.height < 170) {
//             frameSize.height = 140;
//             if ([[self window] frame].size.height != 140) {
//                 _windowWillResize = YES;
//             }
//         } else if (frameSize.height < 400) {
//             frameSize.height = 400;
//             if ([[self window] frame].size.height == 140) {
//                 _windowWillResize = YES;
//             }
//         }
//     }
//     return frameSize;
// }

// - (void)windowDidResize:(NSNotification *)notification {
//     if (_windowWillResize) {
//         [self updateLayoutWithFrame:[[self window] frame]];
//         _windowWillResize = NO;
//     }
//     if ([[self window] styleMask] & NSFullScreenWindowMask) {
//         return;
//     }
//     [self updateWindowButtons];
//     [[PRDefaults sharedDefaults] setRect:[[self window] frame] forKey:([self miniPlayer] ? PRDefaultsMiniPlayerFrame : PRDefaultsPlayerFrame)];
// }

// - (void)windowDidMove:(NSNotification *)notification {
//     if ([[self window] styleMask] & NSFullScreenWindowMask) {
//         return;
//     }
//     [self updateWindowButtons];
//     [[PRDefaults sharedDefaults] setRect:[[self window] frame] forKey:([self miniPlayer] ? PRDefaultsMiniPlayerFrame : PRDefaultsPlayerFrame)];
// }

#pragma mark - PRWindowDelegate

- (BOOL)window:(NSWindow *)window keyDown:(NSEvent *)event {
    if ([[event characters] length] != 1) {
        return NO;
    }
    BOOL didHandle = NO;
    NSUInteger flags = [NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    UniChar c = [[event characters] characterAtIndex:0];
    if (flags == 0) {
        if (c == 0x20) {
            [[_core now] playPause];
            didHandle = YES;
        }
    } else if (flags == (NSNumericPadKeyMask | NSFunctionKeyMask)) {
        if (c == 0xf703) {
            [[_core now] playNext];
            didHandle = YES;
        } else if (c == 0xf702) {
            [[_core now] playPrevious];
            didHandle = YES;
        }
    }
    return didHandle;
}

#pragma mark - NSSplitViewDelegate

// - (void)splitViewDidResizeSubviews:(NSNotification *)note {
//     if (_resizingSplitView) {
//         return;
//     }
//     if ([self window].frame.size.width - [nowPlayingSuperview frame].size.width < 700) {
//         if (!([[self window] styleMask] & NSFullScreenWindowMask)) {
//             NSRect frame = [[self window] frame];
//             frame.size.width = [nowPlayingSuperview frame].size.width + 700;
//             [[self window] setFrame:frame display:YES];
//         } else {
//             [_splitView setPosition:[self window].frame.size.width-700 ofDividerAtIndex:0];
//         }
//     }
//     [self updateSplitView];
//     [[PRDefaults sharedDefaults] setFloat:[nowPlayingSuperview frame].size.width forKey:PRDefaultsSidebarWidth];
// }

// - (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview {
//     if (subview == nowPlayingSuperview) {
//         return NO;
//     }
//     return YES;
// }

// - (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex {
//     if (proposedPosition < 185) {
//         return 185;
//     } else if (proposedPosition > 500) {
//         return 500;
//     } else {
//         return proposedPosition;
//     }
// }

@end
