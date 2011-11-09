//
//  PHTextCheckingResults.h
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//



@interface PHTextCheckingResult : NSTextCheckingResult

//range within the attributed string
@property (atomic, assign) NSRange range;
@end
