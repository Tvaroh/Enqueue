#import "PRControlsViewController.h"
#import "BWTexturedSlider.h"
#import "PRAlbumArtController.h"
#import "PRCore.h"
#import "PRDb.h"
#import "PRGradientView.h"
#import "PRHeaderBox.h"
#import "PRHyperlinkButton.h"
#import "PRLibrary.h"
#import "PRLibraryViewController.h"
#import "PRMainWindowController.h"
#import "PRMoviePlayer.h"
#import "PRNowPlayingController.h"
#import "PRNowPlayingViewController.h"
#import "PRSliderCell.h"
#import "PRBrowserViewController.h"
#import "PRTimeFormatter.h"
#import "PRDefaults.h"
#import "PRProgressManager.h"
#import "PROperationProgress.h"
#import "NSParagraphStyle+Extensions.h"
#import "NSAttributedString+Extensions.h"

@implementation PRControlsViewController {
    __weak PRCore *_core;
    __weak PRDb *_db;
    __weak PRNowPlayingController *_now;
    
    IBOutlet NSButton *playPause;
    IBOutlet NSButton *next;
    IBOutlet NSButton *previous;
    IBOutlet NSButton *shuffle;
    IBOutlet NSButton *repeat;
    
    IBOutlet PRHeaderBox *_box;
    IBOutlet PRHyperlinkButton *titleButton;
    IBOutlet NSTextField *_artistAlbumField;
    
    IBOutlet NSSlider *controlSlider;
    IBOutlet NSTextField *_currentTime;
    IBOutlet NSTextField *duration;
    
    IBOutlet NSImageView *__weak albumArtView;
    
    IBOutlet NSButton *_volumeButton;
    IBOutlet NSSlider *_volumeSlider;
    
    IBOutlet NSView *_containerView;
    IBOutlet PRGradientView *gradientView;
    
    IBOutlet PRGradientView *_progressDivider;
    IBOutlet NSTextField *_progressTextField;
    IBOutlet NSTextField *_progressPercentTextField;
    IBOutlet NSButton *_progressButton;
    
    BOOL _progressHidden;
}

- (id)initWithCore:(PRCore *)core {
    if (!(self = [super initWithNibName:@"PRControlsView" bundle:nil])) {return nil;}
    _core = core;
    _db = [core db];
    _now = [core now];
    return self;
}

- (void)awakeFromNib {
    // Time
    [controlSlider setCell:[[PRSliderCell alloc] init]];
    [controlSlider setMinValue:0.0];
    [controlSlider setTarget:self];
    [controlSlider setAction:@selector(setCurrentTime:)];
        
    // Buttons
    [playPause setTarget:_now];
    [playPause setAction:@selector(playPause)];
    [previous setTarget:_now];
    [previous setAction:@selector(playPrevious)];
    [next setTarget:_now];
    [next setAction:@selector(playNext)];
    [shuffle setTarget:_now];
    [shuffle setAction:@selector(toggleShuffle)];
    [repeat setTarget:_now];
    [repeat setAction:@selector(toggleRepeat)];
    [titleButton setTarget:self];
    [titleButton setAction:@selector(showInLibrary)];
    
    [playPause setToolTip:@"Play or Pause current song."];
    [next setToolTip:@"Play next song."];
    [previous setToolTip:@"Play previous song."];
    [shuffle setToolTip:@"Toggle shuffle."];
    [repeat setToolTip:@"Toggle repeat."];
    [_volumeSlider setToolTip:@"Change volume."];
    [titleButton setToolTip:@"Reveal current song in library."];
    
    // Volume
    [_volumeSlider setMaxValue:1];
    [_volumeSlider setMinValue:0];
    [_volumeSlider setTarget:self];
    [_volumeSlider setAction:@selector(setVolume:)];
    [_volumeButton setTarget:self];
    [_volumeButton setAction:@selector(mute)];
    
    // UI
    NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
                             [NSColor colorWithCalibratedWhite:0.75 alpha:0.0], 0.0,
                             [NSColor colorWithCalibratedWhite:0.5 alpha:0.0], 1.0,
                             nil];
    [gradientView setVerticalGradient:gradient];
    // gradient = [[NSGradient alloc] initWithColorsAndLocations:
    //              [NSColor colorWithCalibratedWhite:0.96 alpha:1.0], 0.0,
    //              [NSColor colorWithCalibratedWhite:0.75 alpha:1.0], 1.0,
    //              nil];
    // [gradientView setAltVerticalGradient:gradient];
    // [gradientView setTopBorder:[NSColor colorWithCalibratedWhite:0.55 alpha:1.0]];
    // [gradientView setTopBorder2:[NSColor colorWithCalibratedWhite:1.0 alpha:0.5]];
    
    // Task Manager
    [[_core taskManager] addObserver:self forKeyPath:@"tasks" options:0 context:nil];
    [_progressDivider setColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
    [_progressDivider setBotBorder:[NSColor colorWithCalibratedWhite:1.0 alpha:0.8]];
    [_progressButton setTarget:[_core taskManager]];
    [_progressButton setAction:@selector(cancel)];
    
    // Notifications
    [[NSNotificationCenter defaultCenter] observeItemsChanged:self sel:@selector(updateControls)];
    [[NSNotificationCenter defaultCenter] observeShuffleChanged:self sel:@selector(updateControls)];
    [[NSNotificationCenter defaultCenter] observeRepeatChanged:self sel:@selector(updateControls)];
    [[NSNotificationCenter defaultCenter] observeTimeChanged:self sel:@selector(updatePlayButton)];
    [[NSNotificationCenter defaultCenter] observePlayingFileChanged:self sel:@selector(updateControls)];
    [[NSNotificationCenter defaultCenter] observePlayingChanged:self sel:@selector(updateControls)];
    [[NSNotificationCenter defaultCenter] observeVolumeChanged:self sel:@selector(updateVolume)];
    
    _progressHidden = [[[_core taskManager] tasks] count] == 0; // set initial value so it doesn't immediately update
    [self updateControls];
    [self updateLayout];
    [self updateVolume];
    [self updateProgress];
}

#pragma mark - properties

@synthesize albumArtView = albumArtView;

#pragma mark - Update

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [_core taskManager] && [keyPath isEqualToString:@"tasks"]) {
        [self updateProgress];
    }
}

- (void)updateLayout {
    [_volumeButton setHidden:[[_core win] miniPlayer]];
    [_artistAlbumField setHidden:![[_core win] miniPlayer]];
    if (![[_core win] miniPlayer]) {
        [_containerView removeFromSuperview];
        for (NSView *i in [NSArray arrayWithObjects:playPause, next, previous, shuffle, repeat, nil]) {
            [i removeFromSuperview];
            [[self view] addSubview:i];
        }
        
        NSRect frame = [previous frame];
        frame.origin.x = 25;
        frame.origin.y = floor([[self view] frame].size.height/2 - [previous frame].size.height/2);
        [previous setFrame:frame];
        [previous setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin];
        
        frame = [playPause frame];
        frame.origin.x = floor([previous frame].origin.x + [previous frame].size.width - 3);
        frame.origin.y = floor([[self view] frame].size.height/2 - [playPause frame].size.height/2);
        [playPause setFrame:frame];
        [playPause setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin];
        
        frame = [next frame];
        frame.origin.x = floor([playPause frame].origin.x + [playPause frame].size.width - 3);
        frame.origin.y = floor([[self view] frame].size.height/2 - [next frame].size.height/2);
        [next setFrame:frame];
        [next setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin];
        
        frame = [_volumeButton frame];
        frame.origin.x = 160;
        frame.origin.y = floor([[self view] frame].size.height/2 - [_volumeButton frame].size.height/2 + 1);
        [_volumeButton setFrame:frame];
        [_volumeButton setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin];
        
        frame = [_volumeSlider frame];
        frame.origin.x = floor([_volumeButton frame].origin.x + [_volumeButton frame].size.width - 5);
        frame.origin.y = floor([[self view] frame].size.height/2 - [_volumeSlider frame].size.height/2);
        [_volumeSlider setFrame:frame];
        [_volumeSlider setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin];
        
        frame = [repeat frame];
        frame.origin.x = floor([[self view] frame].size.width - 25 - [repeat frame].size.width);
        frame.origin.y = floor([[self view] frame].size.height/2 - [repeat frame].size.height/2);
        [repeat setFrame:frame];
        [repeat setAutoresizingMask:NSViewMinYMargin|NSViewMinXMargin];
        
        frame = [shuffle frame];
        frame.origin.x = floor([repeat frame].origin.x - 10 - [shuffle frame].size.width);
        frame.origin.y = floor([[self view] frame].size.height/2 - [shuffle frame].size.height/2);
        [shuffle setFrame:frame];
        [shuffle setAutoresizingMask:NSViewMinYMargin|NSViewMinXMargin];
        
        frame = [_box frame];
        frame.origin.x = 300;
        frame.origin.y = floor([[self view] frame].size.height/2 - 42/2);
        frame.size.width = [[self view] frame].size.width - 390;
        frame.size.height = 42;
        [_box setFrame:frame];
        
        frame = [titleButton frame];
        frame.origin.x = 25;
        frame.origin.y = 17;
        frame.size.width = [_box frame].size.width - 50 - 80;
        [titleButton setFrame:frame];
        
        frame = [controlSlider frame];
        frame.origin.x = 17;
        frame.origin.y = 5;
        frame.size.width = [_box frame].size.width - 34;
        [controlSlider setFrame:frame];
        
        frame = [duration frame];
        frame.size.width = 80;
        frame.origin.y = 15;
        frame.origin.x = [_box frame].size.width - frame.size.width - 25;
        [duration setFrame:frame];
    } else {
        [_containerView removeFromSuperview];
        [[self view] addSubview:_containerView];
        [_box addSubview:_artistAlbumField];
        
        for (NSView *i in @[playPause, next, previous, shuffle, repeat]) {
            [i removeFromSuperview];
            [_containerView addSubview:i];
        }
        
        NSRect frame;
        frame = [_containerView frame];
        frame.origin.x = floor([[self view] frame].size.width/2 - [_containerView frame].size.width/2);
        frame.origin.y = floor(45 - [_containerView frame].size.height/2);
        [_containerView setFrame:frame];
        
        frame = [playPause frame];
        frame.origin.x = floor([_containerView frame].size.width/2 - [playPause frame].size.width/2);
        frame.origin.y = floor(20 - [playPause frame].size.height/2);
        [playPause setFrame:frame];
        [playPause setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin|NSViewMinXMargin];
        
        frame = [previous frame];
        frame.origin.x = floor([playPause frame].origin.x - [previous frame].size.width + 3);
        frame.origin.y = floor(20 - [previous frame].size.height/2);
        [previous setFrame:frame];
        [previous setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin|NSViewMinXMargin];
        
        frame = [next frame];
        frame.origin.x = floor([playPause frame].origin.x + [playPause frame].size.width - 3);
        frame.origin.y = floor(20 - [next frame].size.height/2);
        [next setFrame:frame];
        [next setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin|NSViewMinXMargin];
        
        frame = [repeat frame];
        frame.origin.x = floor([playPause frame].origin.x + [playPause frame].size.width/2 - [repeat frame].size.width - 63);
        frame.origin.y = floor(20 - [repeat frame].size.height/2);
        [repeat setFrame:frame];
        [repeat setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin|NSViewMinXMargin];
        
        frame = [shuffle frame];
        frame.origin.x = floor([playPause frame].origin.x + [playPause frame].size.width/2 + 63);
        frame.origin.y = floor(20 - [shuffle frame].size.height/2);
        [shuffle setFrame:frame];
        [shuffle setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin|NSViewMinXMargin];
        
        frame = [_volumeSlider frame];
        frame.origin.x = floor([[self view] frame].size.width/2 - [_volumeSlider frame].size.width/2);
        frame.origin.y = 0;
        [_volumeSlider setFrame:frame];
        [_volumeSlider setAutoresizingMask:NSViewMinYMargin|NSViewMaxXMargin|NSViewMinXMargin];
        
        frame = [_box frame];
        frame.origin.x = 5;
        frame.origin.y = 63;
        frame.size.width = [[self view] frame].size.width - 10;
        frame.size.height = 42 + 15;
        [_box setFrame:frame];
        
        frame = [titleButton frame];
        frame.origin.x = 7;
        frame.origin.y = 34;
        frame.size.width = [_box frame].size.width - 14;
        [titleButton setFrame:frame];
        
        frame = [_artistAlbumField frame];
        frame.origin.x = 7;
        frame.origin.y = 17;
        frame.size.width = [_box frame].size.width - 14;
        [_artistAlbumField setFrame:frame];
        
        frame = [controlSlider frame];
        frame.origin.x = 35;
        frame.origin.y = 5;
        frame.size.width = [_box frame].size.width - 70;
        [controlSlider setFrame:frame];
        
        frame = [_currentTime frame];
        frame.origin.x = 3;
        frame.origin.y = 1;
        frame.size.width = 40;
        [_currentTime setFrame:frame];
        
        frame = [duration frame];
        frame.size.width = 40;
        frame.origin.x = [_box frame].size.width - frame.size.width - 3;
        frame.origin.y = 1;
        [duration setFrame:frame];
    }
    
    if (!_progressHidden && ![[_core win] miniPlayer]) {
        NSRect frame;
        frame = [titleButton frame];
        frame.size.width -= 165;
        [titleButton setFrame:frame];
        
        frame = [_currentTime frame];
        frame.origin.x -= 165;
        [_currentTime setFrame:frame];
        
        frame = [duration frame];
        frame.origin.x -= 165;
        [duration setFrame:frame];
        
        frame = [controlSlider frame];
        frame.size.width -= 165;
        [controlSlider setFrame:frame];
        
        frame = [_progressDivider frame];
        frame.origin.x = [_box frame].size.width - 175;
        frame.origin.y = 12;
        frame.size.height = 15;
        [_progressDivider setFrame:frame];
        
        frame = [_progressTextField frame];
        frame.size.width = 125;
        frame.origin.x = [_box frame].size.width - 157;
        frame.origin.y = 10;
        [_progressTextField setFrame:frame];
        
        frame = [_progressPercentTextField frame];
        frame.size.width = 30;
        frame.origin.x = [_box frame].size.width - 40;
        frame.origin.y = 10;
        [_progressPercentTextField setFrame:frame];
        
        frame = [_progressButton frame];
        frame.origin.x = [_box frame].size.width - 173;
        frame.origin.y = 12;
        [_progressButton setFrame:frame];
    } else if (!_progressHidden && [[_core win] miniPlayer]) {
        NSRect frame;
        frame = [titleButton frame];
        frame.size.width -= 37;
        [titleButton setFrame:frame];
        
        frame = [_artistAlbumField frame];
        frame.size.width -= 37;
        [_artistAlbumField setFrame:frame];
        
        frame = [duration frame];
        frame.origin.x -= 37;
        [duration setFrame:frame];
        
        frame = [controlSlider frame];
        frame.size.width -= 37;
        [controlSlider setFrame:frame];
        
        frame = [_progressDivider frame];
        frame.origin.x = [_box frame].size.width - 42;
        frame.origin.y = 11;
        frame.size.height = 30;
        [_progressDivider setFrame:frame];
        
        frame = [_progressPercentTextField frame];
        frame.size.width = 30;
        frame.origin.x = [_box frame].size.width - 39;
        frame.origin.y = 18;
        [_progressPercentTextField setFrame:frame];
    }
    
    if ([[_core win] miniPlayer]) {
        [_progressTextField setHidden:YES];
        [_progressButton setHidden:YES];
    } else {
        [_progressTextField setHidden:_progressHidden];
        [_progressButton setHidden:_progressHidden];
    }
    [_progressDivider setHidden:_progressHidden];
    [_progressPercentTextField setHidden:_progressHidden];
    
    [self updateControls];
}

- (void)updateControls {
    [duration setHidden:([_now currentIndex] == 0)];
    [_currentTime setHidden:([_now currentIndex] == 0)];
    [titleButton setHidden:([_now currentIndex] == 0)];
    [controlSlider setHidden:([_now currentIndex] == 0)];
    
    NSImage *shuffleImage = [_now shuffle] ? [NSImage imageNamed:@"ShuffleAlt"] : [NSImage imageNamed:@"Shuffle"];
    NSImage *repeatImage = [_now repeat] ? [NSImage imageNamed:@"RepeatAlt"]: [NSImage imageNamed:@"Repeat"];
    [shuffle setImage:shuffleImage];
    [repeat setImage:repeatImage];
    
    // title
    if ([_now currentIndex] != 0) {
        NSMutableDictionary *titleAttrs = [NSAttributedString defaultBoldUIAttributes];
        NSMutableDictionary *albumAttrs = [NSAttributedString defaultUIAttributes];
        if ([[_core win] miniPlayer]) {
            [titleAttrs setObject:[NSParagraphStyle centerAlignStyle] forKey:NSParagraphStyleAttributeName];
            [albumAttrs setObject:[NSParagraphStyle centerAlignStyle] forKey:NSParagraphStyleAttributeName];
        }
        
        NSString *title = [[_db library] valueForItem:[_now currentItem] attr:PRItemAttrTitle];
        NSString *artist = [[_db library] artistValueForItem:[_now currentItem]];
        NSString *album = [[_db library] valueForItem:[_now currentItem] attr:PRItemAttrAlbum];
        if ([artist isEqualToString:@""]) {
            artist = @"Unknown Artist";
        }
        if ([album isEqualToString:@""]) {
            album = @"Unknown Album";
        }
        
        if (![[_core win] miniPlayer]) {
            NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:title attributes:titleAttrs];
            [attrString appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" - %@ - %@",album,artist]
                                                                                attributes:albumAttrs]];
            [titleButton setAttrString:attrString];
            [titleButton setAltAttrString:attrString];
            [_artistAlbumField setStringValue:@""];
        } else {
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:title attributes:titleAttrs];
            [titleButton setAttrString:attrString];
            
            NSString *string = [NSString stringWithFormat:@"%@ - %@",album,artist];
            attrString = [[NSAttributedString alloc] initWithString:string attributes:albumAttrs];
            [_artistAlbumField setAttributedStringValue:attrString];
        }
    } else {
        [_artistAlbumField setStringValue:@""];
    }
        
    // AlbumArt
    NSImage *albumArt;
    if ([_now currentIndex] != 0) {
        albumArt = [[_db albumArtController] artworkForItem:[_now currentItem]] ?: [NSImage imageNamed:@"PREmptyAlbumArt.png"];
    } else {
        albumArt = [NSImage imageNamed:@"PRNothingPlaying.png"];
    }
    [albumArtView setImage:albumArt];
    [self updatePlayButton];
}

- (void)updatePlayButton {
    [controlSlider setMaxValue:[[_now mov] duration]];
    [controlSlider setIntegerValue:[[_now mov] currentTime]];
    
    NSImage *image = [[_now mov] isPlaying] ? [NSImage imageNamed:@"PauseButton"] : [NSImage imageNamed:@"PlayButton"];
    [playPause setImage:image];
    
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.3]];
    [shadow setShadowOffset:NSMakeSize(1.0, -1.1)];
    NSDictionary *attributes = @{
        NSFontAttributeName:[NSFont fontWithName:@"LucidaGrande" size:10],
        NSForegroundColorAttributeName:[NSColor colorWithDeviceWhite:0.3 alpha:1.0],
        NSParagraphStyleAttributeName:[NSParagraphStyle rightAlignStyle],
        NSShadowAttributeName:shadow};
    NSString *currentTime_ = [[[PRTimeFormatter alloc] init] stringForObjectValue:[NSNumber numberWithLong:[[_now mov] currentTime]]];
    NSDictionary *attributes2 = @{
        NSFontAttributeName:[NSFont fontWithName:@"LucidaGrande" size:10],
        NSForegroundColorAttributeName:[NSColor colorWithDeviceWhite:0.3 alpha:1.0],
        NSParagraphStyleAttributeName:[NSParagraphStyle leftAlignStyle],
        NSShadowAttributeName:shadow};
    NSString *duration_ = [[[PRTimeFormatter alloc] init] stringForObjectValue:[NSNumber numberWithLong:[[_now mov] duration]]];
    
    if (![[_core win] miniPlayer]) {
        NSString *string = [NSString stringWithFormat:@"%@ / %@",currentTime_, duration_];
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:string attributes:attributes];
        [duration setAttributedStringValue:attrString];
        [_currentTime setStringValue:@""];
    } else {
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:currentTime_ attributes:attributes];
        [_currentTime setAttributedStringValue:attrString];
        attrString = [[NSAttributedString alloc] initWithString:duration_ attributes:attributes2];
        [duration setAttributedStringValue:attrString];
    }
}

- (void)updateVolume {
    float volume = [[_now mov] volume];
    NSImage *image;
    if (volume == 0) {
        image = [NSImage imageNamed:@"NowSpeaker1"];
    } else if (volume < 0.33) {
        image = [NSImage imageNamed:@"NowSpeaker1"];
    } else if (volume < 0.66) {
        image = [NSImage imageNamed:@"NowSpeaker2"];
    } else {
        image = [NSImage imageNamed:@"NowSpeaker3"];
    }
    [_volumeButton setImage:image];
    [_volumeSlider setFloatValue:volume];
}

- (void)updateProgress {
    BOOL prevProgressHidden = _progressHidden;
    _progressHidden = [[[_core taskManager] tasks] count] == 0;
    if (prevProgressHidden != _progressHidden) {
        [self updateLayout];
    }

    if (_progressHidden) {
        return;
    }
    PROperationProgress *task = [[[_core taskManager] tasks] objectAtIndex:0];

    NSDictionary *attributes = [NSAttributedString defaultUIAttributes];
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:[task title] attributes:attributes];
    [_progressTextField setAttributedStringValue:attributedString];
    
    NSString *string = [NSString stringWithFormat:@"%d%%", [task percent]];
    attributedString = [[NSAttributedString alloc] initWithString:string attributes:attributes];
    [_progressPercentTextField setAttributedStringValue:attributedString];
}

#pragma mark - Action

- (void)showInLibrary {
    if (![_now currentItem]) {
        return;
    }
    if (![[_core win] miniPlayer]) {
        [[_core win] setCurrentMode:PRWindowModeLibrary];
        [[[_core win] libraryViewController] setCurrentList:[[_db playlists] libraryList]];
        [[[[_core win] libraryViewController] currentViewController] highlightItem:[_now currentItem]];
    } 
    [[[_core win] nowPlayingViewController] higlightPlayingFile];
}

- (void)mute {
    [[_now mov] setVolume:0];
}

- (void)setVolume:(id)sender {
    [[_now mov] setVolume:[_volumeSlider floatValue]];
}

- (void)setCurrentTime:(id)sender {
    [[_now mov] setCurrentTime:[controlSlider integerValue]];
}

@end
