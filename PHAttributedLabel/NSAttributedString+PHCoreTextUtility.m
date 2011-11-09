//
//  NSAttributedString+PHCoreTextUtility.m
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import "NSAttributedString+PHCoreTextUtility.h"

@implementation NSAttributedString (PHCoreTextUtility)

+ (NSAttributedString *)attributedStringWithString:(NSString *)string {
    return [self attributedStringWithString:string withAttributes:nil];
}

+ (NSAttributedString *)attributedStringWithString:(NSString *)string withAttributes:(NSDictionary *)attributes {
    NSAttributedString *attributedString = [[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease];
    return attributedString;
}



- (CTLineRef)CTLine {
    CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)self);
    
#if __has_feature(objc_arc)
    CFBridgingRelease(line);
#else
    [(id)line autorelease];
#endif

    return line;
}

@end
