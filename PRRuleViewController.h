#import <Cocoa/Cocoa.h>
#import "PRLibrary.h"


@class PRLibrary;

@interface PRRuleViewController : NSCollectionViewItem <NSTableViewDataSource>
{
	IBOutlet NSView *listView;
	IBOutlet NSView *rangeView;
	IBOutlet NSView *addView;
	IBOutlet NSTableView *tableView;
	IBOutlet NSBox *box;
	IBOutlet NSPopUpButton *popUpButton;
	IBOutlet NSButton *addButton;
	IBOutlet NSButton *closeButton;
	IBOutlet NSTextField *textField;
	NSMenu *menu;
	
	NSArray *array; // datasource
	
	PRLibrary *lib;
}

// init
- (id)initWithLib:(PRLibrary *)lib_;

// accessors
- (void)setLib:(PRLibrary *)newLib;

// update
- (void)update;

// action
- (void)menuAction:(id)sender;
- (void)delete;
- (void)add;

@end
