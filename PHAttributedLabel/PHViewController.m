//
//  PHViewController.m
//  PHAttributedLabel
//
//  Created by Pier-Olivier Thibault on 11-11-08.
//  Copyright (c) 2011 25th Avenue. All rights reserved.
//

#import "PHViewController.h"

@implementation PHViewController

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.attributedLabel = [[[PHAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 100)] autorelease];
//    self.attributedLabel = [[[PHAttributedLabel alloc] initWithFrame:CGRectMake(0, 0, 200, 100)] autorelease];
    self.attributedLabel.backgroundColor = [UIColor clearColor];
    self.attributedLabel.font = [UIFont systemFontOfSize:14.0];
//    self.attributedLabel.textInsets = UIEdgeInsetsMake(12, 4, 4, 4);
    self.attributedLabel.numberOfLines = 0;
    self.attributedLabel.textAlignment = UITextAlignmentRight;
    self.attributedLabel.shadowColor = [UIColor whiteColor];
    self.attributedLabel.textColor  = [UIColor redColor];
    self.attributedLabel.shadowOffset = CGSizeMake(0, 1);
    self.attributedLabel.lineBreakMode = UILineBreakModeTailTruncation;
    
    self.attributedLabel.text = @"Ground round hamburger brisket, meatloaf shankle sausage strip steak flank pork loin pig. Ground round corned beef meatball tenderloin, andouille turkey sausage pork belly. Ham t-bone shoulder, flank spare ribs kielbasa capicola pancetta short loin meatball andouille beef bresaola. Corned beef tenderloin spare ribs tongue. Tail tenderloin tongue, kielbasa turducken tri-tip swine corned beef shoulder strip steak chuck short ribs hamburger bacon. Tail shankle rump, jerky shank tri-tip strip steak ball tip meatball jowl venison pork belly beef ribs short loin. Beef bresaola turducken, fatback tongue leberkäse jowl.";
    
//    self.attributedLabel.text = @"Test";

    self.label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 200, CGRectGetWidth(self.view.frame), 100)] autorelease];
    self.label.backgroundColor = [UIColor clearColor];
    self.label.font = [UIFont systemFontOfSize:14.0];
    self.label.numberOfLines = 0;
    self.label.textAlignment = UITextAlignmentRight;
    self.label.lineBreakMode = UILineBreakModeTailTruncation;
    self.label.textColor        = [UIColor blueColor];
    self.label.shadowColor = [UIColor whiteColor];
    self.label.shadowOffset = CGSizeMake(0, 1);

    self.label.text = @"Ground round hamburger brisket, meatloaf shankle sausage strip steak flank pork loin pig. Ground round corned beef meatball tenderloin, andouille turkey sausage pork belly. Ham t-bone shoulder, flank spare ribs kielbasa capicola pancetta short loin meatball andouille beef bresaola. Corned beef tenderloin spare ribs tongue. Tail tenderloin tongue, kielbasa turducken tri-tip swine corned beef shoulder strip steak chuck short ribs hamburger bacon. Tail shankle rump, jerky shank tri-tip strip steak ball tip meatball jowl venison pork belly beef ribs short loin. Beef bresaola turducken, fatback tongue leberkäse jowl.";
    
    [self.view addSubview:self.attributedLabel];
    [self.view addSubview:self.label];
}

- (void)dealloc {
    self.attributedLabel    = nil;
    self.label              = nil;
    [super dealloc];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@synthesize attributedLabel = _attributedLabel;
@synthesize label           = _label;
@end
