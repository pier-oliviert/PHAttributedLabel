//
//  PHAttributedLabel.m
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import "PHAttributedLabel.h"
#import "NSAttributedString+PHCoreTextUtility.h"

static NSString * const kPHAttributedLabelCachedLineKey     = @"kPHAttributedLabelCachedLineKey";
static NSString * const kPHAttributedLabelCachedAscentKey   = @"kPHAttributedLabelCachedAscentKey";
static NSString * const kPHAttributedLabelCachedDescentKey  = @"kPHAttributedLabelCachedDescentKey";
static NSString * const kPHAttributedLabelCachedLeadingKey  = @"kPHAttributedLabelCachedLeadingKey";
static NSString * const kPHAttributedLabelCachedWidthKey    = @"kPHAttributedLabelCachedWidthKey";
static NSString * const kPHAttributedLabelCachedRectKey     = @"kPHAttributedLabelCachedRectKey";

NSUInteger const kPHAttributedLabelAutoDetectDisabled       = 0;

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



@interface PHAttributedLabel () <UIGestureRecognizerDelegate>

- (void)initialize;

- (void)labelTouched:(UIGestureRecognizer *)gestureRecognizer;

- (CGRect)drawLine:(CTLineRef)line atPosition:(CGPoint)position withContext:(CGContextRef)context usingInfo:(NSDictionary *)lineInfo;

- (NSTextCheckingResult *)textCheckingResultWithIndex:(NSInteger)idx;
- (void)callBlockLinkedToResult:(NSTextCheckingResult *)result;


@property (nonatomic, retain) NSMutableAttributedString *mutableAttributedString;

@property (nonatomic, retain) NSTextCheckingResult *highlightedResult;

//Those properties are assigned because compile complains when retaining. We do retain though.
@property (nonatomic, assign) CFMutableArrayRef cachedContent;
@property (nonatomic, assign) CTTypesetterRef typesetter;
@property (nonatomic, assign) CFMutableDictionaryRef links;

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
    self.links                      = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    self.userInteractionEnabled     = YES;
    
    UIGestureRecognizer *gesture    = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTouched:)] autorelease];
    gesture.delegate                = self;
    
    [self addGestureRecognizer:gesture];
    
    [self addObserver:self forKeyPath:@"font" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"textInsets" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"baselineAdjustment" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"minimumFontSize" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"numberOfLines" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"lineBreakMode" options:NSKeyValueObservingOptionNew context:nil];
    [self addObserver:self forKeyPath:@"adjustsFontSizeToFitWidth" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"font"];
    [self removeObserver:self forKeyPath:@"textInsets"];
    [self removeObserver:self forKeyPath:@"numberOfLines"];
    [self removeObserver:self forKeyPath:@"lineBreakMode"];
    [self removeObserver:self forKeyPath:@"baselineAdjustment"];
    [self removeObserver:self forKeyPath:@"adjustsFontSizeToFitWidth"];
    [self removeObserver:self forKeyPath:@"minimumFontSize"];
    
    self.mutableAttributedString    = nil;
    self.typesetter                 = nil;
    self.cachedContent              = nil;
    self.links                      = nil;
    self.highlightedResult          = nil;
    
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
    CGRect rect;
    f_pos   = CGPointApplyAffineTransform(position, CGAffineTransformMakeScale(1, -1));
    
    ascent  = [[lineInfo valueForKey:kPHAttributedLabelCachedAscentKey] floatValue];
    descent = [[lineInfo valueForKey:kPHAttributedLabelCachedDescentKey] floatValue];
    leading = [[lineInfo valueForKey:kPHAttributedLabelCachedLeadingKey] floatValue];
    width   = [[lineInfo valueForKey:kPHAttributedLabelCachedWidthKey] floatValue];
    
    f_pos.x += CTLineGetPenOffsetForFlush(line, self.textAlignment * 0.5f, CGRectGetWidth(self.bounds) - (self.textInsets.left + self.textInsets.right));
    
    f_pos.y -= ascent;
    
    CGContextSetTextPosition(context, f_pos.x, f_pos.y);
    CTLineDraw(line, context);
    
    //Transform point for iOS coordinate system. This rect will be used to practive hit testing.
    rect = CGRectMake(CGPointApplyAffineTransform(f_pos, CGAffineTransformMakeScale(1, -1)).x,
                      position.y,
                      width, 
                      ascent + descent + leading);
    
    [lineInfo setValue:[NSValue valueWithCGRect:rect] forKey:kPHAttributedLabelCachedRectKey];

    return rect;
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
        if (![[self.mutableAttributedString string] isEqualToString:text]) {
            super.text                          = text;
            self->_labelFlags.isContentCached   = NO;

            [[self.mutableAttributedString mutableString] setString:text];
            [self.mutableAttributedString addAttributes:[self labelWideAttributes]
                                                  range:NSMakeRange(0, [self.mutableAttributedString length])];            
        }
    } 
    
    else if ([text isKindOfClass:[NSAttributedString class]]) {
        if (![self.mutableAttributedString isEqualToAttributedString:text]) {
            [self.mutableAttributedString setAttributedString:text];

            super.text                          = [text string];
            self->_labelFlags.isContentCached   = NO;
        }
    } else {
        NSAssert(text == nil, @"argument passed can either be a NSString, NSAttributedString or nil.", nil);
        super.text = text;
        [self.mutableAttributedString deleteCharactersInRange:NSMakeRange(0, [self.mutableAttributedString length])];
    }
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


- (void)setLinks:(CFMutableDictionaryRef)links {
    if (self->_links) {
        CFRelease(self->_links);
        self->_links = nil;
    }
    if (links) {
        self->_links = links;
    }
}


#pragma mark - Link
- (NSTextCheckingResult *)textCheckingResultWithIndex:(NSInteger)idx {
    
    NSTextCheckingResult *validResult = nil;
    
    for (NSTextCheckingResult *result in [(NSDictionary *)self.links allKeys]) {
        NSRange range = result.range;
        
        if ((idx - range.location <= range.length)) {
            validResult = result;
            break;
        }
    }
    
    return validResult;
}


- (void)callBlockLinkedToResult:(NSTextCheckingResult *)result {
    void(^block)(NSTextCheckingResult *result) = CFDictionaryGetValue(self.links, result);
    block(result);
}



- (void)addLinkInRange:(NSRange)range detectDataType:(NSInteger)dataTypes usingBlock:(void(^)(NSTextCheckingResult *result))block {
    __block BOOL detectedTypes = NO;
    
    if (dataTypes) {
        NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:dataTypes error:nil];
        [dataDetector enumerateMatchesInString:[self.mutableAttributedString string]
                                       options:NSMatchingReportCompletion 
                                         range:range
                                    usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                                        
                                        CFDictionarySetValue(self.links, result, [Block_copy(block) autorelease]);
                                        
                                        detectedTypes = YES;
                                    }];        
    }
    
    if (!detectedTypes) {
        CFDictionarySetValue(self.links, [NSTextCheckingResult linkCheckingResultWithRange:range URL:nil], [Block_copy(block) autorelease]);
    }
}


- (void)removeAllLinks {
    CFDictionaryRemoveAllValues(self.links);
}

#pragma mark - UIGestureRecognizer
- (void)labelTouched:(UIGestureRecognizer *)gestureRecognizer {
    if (self.highlightedResult && gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        [self callBlockLinkedToResult:self.highlightedResult];
        self.highlightedResult = nil;        
    }
}

#pragma mark Delegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([(NSDictionary *)self.links count] == 0) {
        return NO;
    } 
    else {
        CGPoint point   = [touch locationInView:self];
        
        for (NSDictionary *dictionary in (NSArray *)self.cachedContent) {
            CGRect frame = [[dictionary valueForKeyPath:kPHAttributedLabelCachedRectKey] CGRectValue];
            
            if (CGRectContainsPoint(frame, point)) {
                CTLineRef line              = CFDictionaryGetValue((CFDictionaryRef)dictionary, kPHAttributedLabelCachedLineKey);
                CFIndex idx                 = CTLineGetStringIndexForPosition(line, point);
                
                self.highlightedResult      = [self textCheckingResultWithIndex:idx];
                break;
            }
        }    

        return YES;
    }
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
@synthesize highlightedResult       = _highlightedResult;
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
