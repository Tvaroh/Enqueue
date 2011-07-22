#import "PRScroller.h"

#ifndef NSAppKitVersionNumber10_6
#define NSAppKitVersionNumber10_6 1038
#endif


@implementation PRScroller

- (void)drawRect:(NSRect)dirtyRect
{
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [super drawRect:dirtyRect];
    } else {
        [self drawKnobSlotInRect:dirtyRect highlight:FALSE];
        [self drawKnob];
    }
}

- (void)drawKnob {
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [super drawKnob];
    } else {
        NSRect position = [self rectForPart:NSScrollerKnob];
        if (position.size.height == 0) {
            return;
        }
        
        NSImage *topImg = [NSImage imageNamed:@"PRVerticalScrollerThinTop"];
        NSImage *centerImg = [NSImage imageNamed:@"PRVerticalScrollerThinCenter"];
        NSImage *bottomImg = [NSImage imageNamed:@"PRVerticalScrollerThinBottom"];
        
        NSSize topImgSize = [topImg size];
        NSSize centerImgSize = [centerImg size];
        NSSize bottomImgSize = [bottomImg size];
        
        
        [topImg setFlipped:YES];
        [topImg drawInRect:NSMakeRect(position.origin.x, position.origin.y,
                                      topImgSize.width, topImgSize.height)
                  fromRect:NSMakeRect(0, 0, topImgSize.width, topImgSize.height)
                 operation:NSCompositeSourceOver
                  fraction:1.0];
        
        int i = 0;
        for (i = (position.origin.y+topImgSize.height); i < (position.origin.y +
                                                             (position.size.height-bottomImgSize.height)); i += centerImgSize.height) {
            [centerImg drawInRect:NSMakeRect(position.origin.x, i,
                                             centerImgSize.width, centerImgSize.height)
                         fromRect:NSMakeRect(0, 0, centerImgSize.width,
                                             centerImgSize.height)
                        operation:NSCompositeSourceOver
                         fraction:1.0];
        }
        
        [bottomImg setFlipped:YES];
        [bottomImg drawInRect:NSMakeRect(position.origin.x, position.origin.y+
                                         (position.size.height-bottomImgSize.height), bottomImgSize.width, bottomImgSize.height)
                     fromRect:NSMakeRect(0, 0, bottomImgSize.width,
                                         bottomImgSize.height)
                    operation:NSCompositeSourceOver
                     fraction:1.0];
    }
}

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [super drawKnobSlotInRect:slotRect highlight:flag];
    } else {
    }
}

- (void)drawParts
{
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [super drawParts];
    } else {
        for (int i = 0; i < 7; i++) {
            [[NSColor colorWithDeviceRed:218./255 green:223./255 blue:230./255 alpha:1.0] set];
            [NSBezierPath fillRect:[self rectForPart:i]];
        }
    }
}

- (void)drawArrow:(NSScrollerArrow)arrow highlight:(BOOL)flag
{
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [super drawArrow:arrow highlight:flag];
    } else {
    }
}

- (void)mouseDown:(NSEvent *)event
{
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [super mouseDown:event];
    } else {
        NSPoint p = [event locationInWindow];
        NSPoint q = [self convertPoint:p fromView:nil];
        if (NSPointInRect(q, [self rectForPart:NSScrollerKnob])) {
            [super mouseDown:event];
        } else {
            [[(NSScrollView *)[self superview] documentView] mouseDown:event];
        }
    }
}

@end
