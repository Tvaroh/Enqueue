#import "PRSidebarImageView.h"
#import "NSBezierPath+Extensions.h"

@implementation PRSidebarImageView

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor blackColor] set];
    [NSBezierPath fillRect:[self frame]];
    [super drawRect:dirtyRect];
    [[NSColor lightGrayColor] set];
    [NSBezierPath fillRect:[NSBezierPath topBorderOfRect:[self frame]]];
}

@end
