#import "PRTask.h"


@implementation PRTask

// ========================================
// Initialization
// ========================================

- (id)init
{
    if (!(self = [super init])) {return nil;}
    shouldCancel = FALSE;
    return self;
}

- (void)dealloc
{
    [title release];
    [value release];
    [super dealloc];
}

// ========================================
// Accessors
// ========================================

@synthesize title;
@synthesize value;
@synthesize shouldCancel;
@synthesize background;

@end
