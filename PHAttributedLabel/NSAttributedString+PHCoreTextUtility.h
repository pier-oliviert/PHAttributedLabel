//
//  NSAttributedString+PHCoreTextUtility.h
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import <CoreText/CoreText.h>

@interface NSAttributedString (PHCoreTextUtility)

//First one is naked: No attributes will be copied, on the second, you can pass attributes so it keeps the same style.
+ (NSAttributedString *)attributedStringWithString:(NSString *)string;
+ (NSAttributedString *)attributedStringWithString:(NSString *)string withAttributes:(NSDictionary *)attributes;


- (CTLineRef)CTLine; //Autoreleased.
@end
