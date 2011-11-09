//
//  PHAttributedLabel.h
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

@class PHTextCheckingResult;

UIKIT_CLASS_AVAILABLE(4_0)
@interface PHAttributedLabel : UILabel {
@private
    NSMutableAttributedString   *_mutableAttributedString;
    NSMutableArray              *_links;
    UIEdgeInsets                _textInsets;

    CFMutableArrayRef           _cachedContent;
    CTTypesetterRef             _typesetter;
    
    struct {
        BOOL isContentCached:1;
    } _labelFlags;
}

/**
 *  You can either provide your own NSAttributedString or a NSString.
 */
@property (nonatomic, copy) id text;

/*!
    @function           addLinkInRange:detectDataType:usingBlock;
 
    @param Range        This is to set the boundaries of the link you want to set up
 
    @param dataTypes    Will use NSDataDetector to try to find matching data types.
                        You can provide combinations of NSTextCheckingType. 
                        You can also add the other type defined in PHTextCheckingResult. 
                        Different types can be set for different links.
 
                        Passing nil means you don't want to detect the dataType
 
                        If you pass types, NSDataDetector will first try to find all the mathing
                        criteria within the range (Can have more than 1 positive results).
                        If it can't find any, it will add a link that will contain the 
                        whole range.
 
                        However, if you don't provide any type, it will immediately create a link
                        englobing the whole range.

    @param block        This is going to be called when the link will be tapped by the user.
 
    @discussion This `PHAttributedLabel` only has 1 way to set up links. If you set highligted colors, the link will be highlighted when the user highlight the link.
 */
- (void)addLinkInRange:(NSRange)range detectDataType:(NSInteger)dataTypes usingBlock:(void(^)(PHTextCheckingResult *result))block;


- (void)removeAllLinks;

/**
 *  Insets that you can set if you want to add padding to your label.
 */
@property (nonatomic, assign) UIEdgeInsets textInsets;
@end
