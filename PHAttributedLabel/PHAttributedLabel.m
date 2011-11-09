//
//  PHAttributedLabel.m
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import "PHAttributedLabel.h"
#import "PHTextCheckingResult.h"
#import "NSAttributedString+PHCoreTextUtility.h"

static NSString * const kPHAttributedLabelCachedLineKey     = @"kPHAttributedLabelCachedLineKey";
static NSString * const kPHAttributedLabelCachedAscentKey   = @"kPHAttributedLabelCachedAscentKey";
static NSString * const kPHAttributedLabelCachedDescentKey  = @"kPHAttributedLabelCachedDescentKey";
static NSString * const kPHAttributedLabelCachedLeadingKey  = @"kPHAttributedLabelCachedLeadingKey";
static NSString * const kPHAttributedLabelCachedWidthKey    = @"kPHAttributedLabelCachedWidthKey";

@interface PHAttributedLabel (UILineBreakMode)

- (NSDictionary *)attributesWithRange:(CFRange)range andTruncationType:(CTLineTruncationType)truncationType;

- (CTLineRef)truncatedLineFromLineInfo:(CFDictionaryRef)lineInfo withLineBreakMode:(UILineBreakMode)lineBreakMode;
- (CTLineRef)truncationLineForUILineBreakMode:(UILineBreakMode)lineBreakMode withAttributes:(NSDictionary *)attributes; //Autorelease or ARC enabled.

//return the index inside the Cached contents. Use that to replace the line (integer = (0 | last object))
- (NSInteger)selectCachedLine:(CTLineRef *)line withLineBreakMode:(UILineBreakMode)lineBreakMode;
@end



@interface PHAttributedLabel (UILabelSettingsAttributes)
- (NSDictionary *)labelWideAttributes;
@end



@interface PHAttributedLabel ()

- (void)initialize;

- (CGRect)drawLine:(CTLineRef)line atPosition:(CGPoint)position withContext:(CGContextRef)context usingInfo:(NSDictionary *)lineInfo;

//Those 2 properties are assigned because compile complains when retaining. We do retain though.
@property (nonatomic, assign) CFMutableArrayRef cachedContent;
@property (nonatomic, assign) CTTypesetterRef typesetter;

@property (nonatomic, retain) NSMutableAttributedString *mutableAttributedString;

@property (nonatomic, retain) NSMutableArray *links;
@end

@implementation PHAttributedLabel

#pragma mark - Life Cycle
- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initialize];
    }
    return self;
}

- (void)initialize {
    self.mutableAttributedString    = [[[NSMutableAttributedString alloc] init] autorelease];
    self.cachedContent              = CFArrayCreateMutable(kCFAllocatorDefault, self.numberOfLines, &kCFTypeArrayCallBacks);
    self.links                      = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];
    
    [self addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"font" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"textInsets" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"numberOfLines" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"lineBreakMode" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"frame"];
    [self removeObserver:self forKeyPath:@"bounds"];
    [self removeObserver:self forKeyPath:@"font"];
    [self removeObserver:self forKeyPath:@"textInsets"];
    [self removeObserver:self forKeyPath:@"numberOfLines"];
    [self removeObserver:self forKeyPath:@"lineBreakMode"];
    
    self.mutableAttributedString    = nil;
    self.typesetter                 = nil;
    self.cachedContent              = nil;
    self.links                      = nil;
    
    [super dealloc];
}

#pragma mark - Drawing
- (void)drawTextInRect:(CGRect)rect {
    [self sizeThatFits:rect.size];
    CGContextRef ctx        = UIGraphicsGetCurrentContext();
    CGRect drawnLineFrame   = CGRectMake(self.textInsets.left, self.textInsets.top, 0, 0);
    CGContextSaveGState(ctx);
    
    //This is in order to position the context for Core Text
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGContextScaleCTM(ctx, 1.0f, -1.0f);
    
    //Shadow
    CGContextSetShadowWithColor(ctx, self.shadowOffset, 0, [self.shadowColor CGColor]);
        
    for (NSDictionary *lineInfo in (NSArray *)self.cachedContent) {
        CTLineRef line  = (CTLineRef)[lineInfo valueForKey:kPHAttributedLabelCachedLineKey];
        drawnLineFrame  = [self drawLine:line atPosition:CGPointMake(CGRectGetMinX(drawnLineFrame), CGRectGetMaxY(drawnLineFrame))
                             withContext:ctx 
                               usingInfo:lineInfo];
    }
    
    CGContextRestoreGState(ctx);
}


- (CGRect)drawLine:(CTLineRef)line atPosition:(CGPoint)position withContext:(CGContextRef)context usingInfo:(NSDictionary *)lineInfo {
    CGFloat width, ascent, descent, leading;
    CGPoint f_pos; //flipped position.

    f_pos   = CGPointApplyAffineTransform(position, CGAffineTransformMakeScale(1, -1));
    
    ascent  = [[lineInfo valueForKey:kPHAttributedLabelCachedAscentKey] floatValue];
    descent = [[lineInfo valueForKey:kPHAttributedLabelCachedDescentKey] floatValue];
    leading = [[lineInfo valueForKey:kPHAttributedLabelCachedLeadingKey] floatValue];
    width   = [[lineInfo valueForKey:kPHAttributedLabelCachedWidthKey] floatValue];
    
    f_pos.x += CTLineGetPenOffsetForFlush(line, self.textAlignment * 0.5f, CGRectGetWidth(self.bounds) - (self.textInsets.left + self.textInsets.right));
    
    f_pos.y -= ascent;
    
    CGContextSetTextPosition(context, f_pos.x, f_pos.y);
    CTLineDraw(line, context);
        
    return CGRectMake(position.x, position.y , width, ascent + descent + leading);
}


#pragma mark - Resizing introspection
- (void)sizeToFit {
}

- (CGSize)sizeThatFits:(CGSize)size {
    if (self->_labelFlags.isContentCached) {
        return self.bounds.size;
    }
    
    CGSize suggestedSize    = CGSizeMake(0, self.textInsets.top + self.textInsets.bottom);
    CGSize drawingSize      = size;
    drawingSize.height      -= (self.textInsets.top + self.textInsets.bottom);
    drawingSize.width       -= (self.textInsets.left + self.textInsets.right);
    
    @synchronized(self) {
        
        self.typesetter                     = CTTypesetterCreateWithAttributedString((CFAttributedStringRef)self.mutableAttributedString);
        
        NSInteger constraintsOnLineCount    = self.numberOfLines > 0 ? self.numberOfLines : NSIntegerMax;
        NSUInteger stringLength             = [self.mutableAttributedString length];
        CFRange range                       = CFRangeMake(0, stringLength);
        
        //empty the cache.
        CFArrayRemoveAllValues(self.cachedContent);
        
        while (constraintsOnLineCount > 0) {
            if (range.length <= 0) {
                break;
            }
            CGFloat width, ascent, descent, leading;
            
            
            CFMutableDictionaryRef lineInfo = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            
            range.length                    = CTTypesetterSuggestLineBreak(self.typesetter, range.location, drawingSize.width);
            
            CTLineRef line                  = CTTypesetterCreateLine(self.typesetter, range);

            width                           = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
            
            //Add the size required if there's room. Break out of loop otherwise.
            if (size.height < (suggestedSize.height + ascent + descent + leading)) {
                //Our string is bigger than what we can present. Truncation!
                CFMutableDictionaryRef lineToTruncateInfo   = nil;
                CTLineRef lineToTruncate                    = nil;
                
                NSInteger idx = [self selectCachedLine:&lineToTruncate withLineBreakMode:self.lineBreakMode];
                
                lineToTruncateInfo = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(self.cachedContent, idx);
                
                CFDictionarySetValue(lineToTruncateInfo, kPHAttributedLabelCachedLineKey, [self truncatedLineFromLineInfo:lineToTruncateInfo withLineBreakMode:self.lineBreakMode]);
                
                //Garbage collection
                CFRelease(lineInfo);
                break;
            }
            
            suggestedSize.height += ascent + descent + leading;
            suggestedSize.width  = MAX(width, size.width);
            
            //Cache the line.
            CFDictionarySetValue(lineInfo, kPHAttributedLabelCachedLineKey,     line);
            CFDictionarySetValue(lineInfo, kPHAttributedLabelCachedWidthKey,    [NSNumber numberWithDouble:width]);
            CFDictionarySetValue(lineInfo, kPHAttributedLabelCachedAscentKey,   [NSNumber numberWithDouble:ascent]);
            CFDictionarySetValue(lineInfo, kPHAttributedLabelCachedLeadingKey,  [NSNumber numberWithDouble:leading]);
            CFDictionarySetValue(lineInfo, kPHAttributedLabelCachedDescentKey,  [NSNumber numberWithDouble:descent]);
            CFArrayAppendValue(self.cachedContent, lineInfo);
            
            //Prepare for next iteration
            range.location += range.length;
            range.length    = stringLength - range.location;
            
            //Garbage collection
            CFRelease(lineInfo);
            
            //decrease constraints
            if (constraintsOnLineCount != NSIntegerMax)
                constraintsOnLineCount--;            
        }

        self->_labelFlags.isContentCached = YES;
    }
    
    return suggestedSize;
}


#pragma mark - Accessories
- (void)setText:(id)text {
    
    if ([text isKindOfClass:[NSString class]]) {
        [[self.mutableAttributedString mutableString] setString:text];
        super.text = text;
    } 
    
    else if ([text superclass] == [NSAttributedString class]) {
        super.text = [text string];
        [self.mutableAttributedString setAttributedString:text];
    }

    [self.mutableAttributedString setAttributes:[self labelWideAttributes]
                                          range:NSMakeRange(0, [self.mutableAttributedString length])];

    
    self->_labelFlags.isContentCached   = NO;
}

- (void)setCachedContent:(CFMutableArrayRef)cachedContent {
    if (self->_cachedContent) {
        CFRelease(self->_cachedContent);
        self->_cachedContent = nil;
    }
    if (cachedContent) {
        self->_cachedContent = cachedContent;
    }
}


- (void)setTypesetter:(CTTypesetterRef)typesetter {
    if (self->_typesetter) {
        CFRelease(self->_typesetter);
        self->_typesetter = nil;
    }
    if (typesetter) {
        self->_typesetter = typesetter;
    }    
}


- (void)setHighlightedTextColor:(UIColor *)highlightedTextColor {
    super.highlightedTextColor = highlightedTextColor;
}

- (void)setMinimumFontSize:(CGFloat)minimumFontSize {
    super.minimumFontSize = minimumFontSize;
    self->_labelFlags.isContentCached = NO;
}


- (void)setBaselineAdjustment:(UIBaselineAdjustment)baselineAdjustment {
    super.baselineAdjustment = baselineAdjustment;
    self->_labelFlags.isContentCached = NO;
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth {
    super.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth;
    self->_labelFlags.isContentCached = NO;
}

#pragma mark - Link
- (void)addLinkInRange:(NSRange)range detectDataType:(NSInteger)dataTypes usingBlock:(void(^)(PHTextCheckingResult *result))block {
    if (dataTypes) {
        NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:dataTypes error:nil];
        [dataDetector enumerateMatchesInString:[self.mutableAttributedString string]
                                       options:NSMatchingReportCompletion 
                                         range:range 
                                    usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                        [self.links addObject:result];
                                    }];        
    }
    
    PHTextCheckingResult *result = [[[PHTextCheckingResult alloc] init] autorelease];
    result.range = range;
}


- (void)removeAllLinks {
    [self.links removeAllObjects];
}

#pragma mark - Key-Value Observing
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    self->_labelFlags.isContentCached   = NO;
}


#pragma mark - Synthesizers
@synthesize mutableAttributedString = _mutableAttributedString;
@synthesize cachedContent           = _cachedContent;
@synthesize typesetter              = _typesetter;
@synthesize textInsets              = _textInsets;
@synthesize links                   = _links;
@dynamic text;
@end




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PHAttributedLabel (UILabelSettingsAttributes)
@implementation PHAttributedLabel (UILabelSettingsAttributes)

- (NSDictionary *)labelWideAttributes {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    CTFontRef font                  = CTFontCreateWithName((CFStringRef)self.font.fontName, self.font.pointSize, NULL);
    CGColorRef textColor            = [self.textColor CGColor];
    
    
    //Setting Attributes
    [attributes setValue:(id)font forKey:(NSString *)kCTFontAttributeName];
    [attributes setValue:(id)textColor forKey:(NSString *)kCTForegroundColorAttributeName];
    
    //Garbage
    CFRelease(font);
    
    return [NSDictionary dictionaryWithDictionary:attributes];
}
@end




//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - PHAttributedLabel (UILineBreakMode)
@implementation PHAttributedLabel (UILineBreakMode)

- (CTLineTruncationType)truncationTypeForUILineBreakMode:(UILineBreakMode)lineBreakMode {
	switch (lineBreakMode) {
		case UILineBreakModeWordWrap:
		case UILineBreakModeCharacterWrap:
		case UILineBreakModeClip:
        case UILineBreakModeTailTruncation:
            return kCTLineTruncationEnd;
            
		case UILineBreakModeHeadTruncation:
            return kCTLineTruncationStart;

		case UILineBreakModeMiddleTruncation:
            return kCTLineTruncationMiddle;
		
        default: return 0;
	}    
}

- (CTLineRef)truncationLineForUILineBreakMode:(UILineBreakMode)lineBreakMode withAttributes:(NSDictionary *)attributes {
    NSString *token = nil;
    
    switch (lineBreakMode) {
		case UILineBreakModeWordWrap:
		case UILineBreakModeCharacterWrap:
		case UILineBreakModeClip:
            token = @"";
            break;
            
		case UILineBreakModeHeadTruncation:
		case UILineBreakModeTailTruncation:
		case UILineBreakModeMiddleTruncation:
        default:
            token = [NSString stringWithCString:"\u2026" encoding:NSUTF8StringEncoding];
	}
    
    return [[NSAttributedString attributedStringWithString:token withAttributes:attributes] CTLine];
}

- (NSInteger)selectCachedLine:(CTLineRef *)line withLineBreakMode:(UILineBreakMode)lineBreakMode {
    NSInteger idx               = ([self truncationTypeForUILineBreakMode:lineBreakMode] == kCTLineTruncationStart) ? 0 : CFArrayGetCount(self.cachedContent) - 1;
    CFDictionaryRef dictionary  = CFArrayGetValueAtIndex(self.cachedContent, idx);
    
    *line                       = CFDictionaryGetValue(dictionary, kPHAttributedLabelCachedLineKey);
    
    return idx;
}

- (NSDictionary *)attributesWithRange:(CFRange)range andTruncationType:(CTLineTruncationType)truncationType {
    NSInteger idx = range.location;

    if (truncationType == kCTLineTruncationMiddle) {
        idx += range.length / 2;
    } else {
        idx += range.length;
    }
    
    return [self.mutableAttributedString attributesAtIndex:idx effectiveRange:nil];
}

- (CTLineRef)truncatedLineFromLineInfo:(CFDictionaryRef)lineInfo withLineBreakMode:(UILineBreakMode)lineBreakMode{
    //Remove 1 pixel because we are "forcing" truncation.
    CTLineRef line                      = CFDictionaryGetValue(lineInfo, kPHAttributedLabelCachedLineKey);
    CGFloat width                       = [(NSNumber *)CFDictionaryGetValue(lineInfo, kPHAttributedLabelCachedWidthKey) floatValue] - CTLineGetTrailingWhitespaceWidth(line) - 1;
    CTLineTruncationType truncationType = [self truncationTypeForUILineBreakMode:lineBreakMode];
    CTLineRef truncationToken           = [self truncationLineForUILineBreakMode:lineBreakMode
                                                                  withAttributes:[self attributesWithRange:CTLineGetStringRange(line)
                                                                                         andTruncationType:truncationType]];
    
    CTLineRef truncatedLine             = CTLineCreateTruncatedLine(line,
                                                                    width,
                                                                    truncationType,
                                                                    truncationToken);
#if __has_feature(objc_arc)
    CFBridgingRelease(truncatedLine);
#else
    [(id)truncatedLine autorelease];
#endif
    
    return truncatedLine;
}

@end
