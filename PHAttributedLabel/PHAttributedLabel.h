//
//  PHAttributedLabel.h
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

UIKIT_CLASS_AVAILABLE(4_0)
@interface PHAttributedLabel : UILabel {
@private
    NSMutableAttributedString   *_mutableAttributedString;
    NSTextCheckingResult        *_highlightedResult;
    
    CFMutableArrayRef           _cachedContent;
    CTTypesetterRef             _typesetter;
    CFMutableDictionaryRef      _links;
    
    UIEdgeInsets                _textInsets;
    
    struct {
        BOOL isContentCached:1;
    } _labelFlags;
}

/*!
    @discussion     You can either provide your own NSAttributedString or a NSString.
 
                    If you provide a NSAttributedString, the default UILabel's option (except for the shadow settings)
                    will be ignored.
 
                    In future version, we could add the possibily to modify the attributes to the underlying mutable
                    attributed string, so someone could pass a NSString and then modify some attributes of it.
 */
@property (nonatomic, copy) id text;


/*!
    @function           addLinkInRange:detectDataType:usingBlock;
 
    @param Range        This is to set the boundaries of the link you want to set up. It's also your responsability
                        to set links that aren't overlapping ranges. If you have overlapping ranges, the result is undefined.
 
    @param dataTypes    Will use NSDataDetector to try to find matching data types.
                        You can provide combinations of NSTextCheckingType. 
                        You can also add the other type defined in PHTextCheckingResult. 
                        Different types can be set for different links.
 
                        Passing kPHAttributedLabelAutoDetectDisabled will disable auto-detection
 
                        If you pass types, NSDataDetector will first try to find all the mathing
                        criteria within the range (Can have more than 1 positive results).
                        If it can't find any, it will add a link that will contain the 
                        whole range.
 
                        However, if you don't provide any type, it will immediately create a link
                        englobing the whole range.

    @param block        This is going to be called when the link will be tapped by the user.
 
    @discussion         This `PHAttributedLabel` only has 1 way to set up links. If you set highligted colors, 
                        the link will be highlighted when the user highlight the link.
 
 */
- (void)addLinkInRange:(NSRange)range detectDataType:(NSInteger)dataTypes usingBlock:(void(^)(NSTextCheckingResult *result))block;


- (void)removeAllLinks;

/**
 *  Insets that you can set if you want to add padding to your label.
 */
@property (nonatomic, assign) UIEdgeInsets textInsets;
@end


extern NSUInteger const kPHAttributedLabelAutoDetectDisabled;