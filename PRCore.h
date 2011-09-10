#import <Cocoa/Cocoa.h>

@class PRDb, PRNowPlayingController, PRMainWindowController, PRFolderMonitor, PRTaskManager,
PRWelcomeSheetController, PRGrowl, PRLastfm;

@interface PRCore : NSObject <NSApplicationDelegate>
{
    IBOutlet NSMenu *mainMenu;
    
    PRWelcomeSheetController *welcomeSheet;
    NSConnection *_connection;
    
	PRDb *db;
    PRDb *db2;
	PRNowPlayingController *now;
	PRMainWindowController *win;
	NSOperationQueue *opQueue;
    PRFolderMonitor *folderMonitor;
    PRTaskManager *taskManager;
    PRGrowl *growl;
    PRLastfm *lastfm;
}

// ========================================
// Properties

@property (readonly) PRDb *db;
@property (readonly) PRDb *db2;
@property (readonly) PRMainWindowController *win;
@property (readonly) PRNowPlayingController *now;
@property (readonly) NSOperationQueue *opQueue;
@property (readonly) PRFolderMonitor *folderMonitor;
@property (readonly) PRTaskManager *taskManager;
@property (readonly) NSMenu *mainMenu;
@property (readonly) PRLastfm *lastfm;

// ========================================
// Actions

- (void)itunesImport:(id)sender;
- (IBAction)showOpenPanel:(id)sender;
- (void)importSheetDidEnd:(NSOpenPanel*)openPanel 
			   returnCode:(NSInteger)returnCode 
				  context:(void*)context;

// ========================================
// Error

- (NSError *)multipleInstancesError;
- (NSError *)couldNotCreateDirectoryError:(NSString *)directory;

@end