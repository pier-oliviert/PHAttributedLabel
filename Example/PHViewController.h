//
//  PHViewController.h
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PHAttributedLabel.h"


@interface PHViewController : UIViewController {
    PHAttributedLabel   *_attributedLabel;
    UILabel             *_label;
}

@property (nonatomic, retain) PHAttributedLabel *attributedLabel;
@property (nonatomic, retain) UILabel *label;
@end
