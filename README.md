# PHAttributedLabel

This class is a direct subclass from **UILabel** and allow you to use a NSAttributedString instead of a normal NSString. Therefore, this class is a drop-in replacement of UILabel. It is highly influenced by OHAttributedLabel & TTTAttributedLabel.

It also gives **support to hyperlinks** with auto-detection support to using NSDataDetector.

### UILabel's method are all implemented
This class supports everything you would expect from a UILabel. Most of the stuff has been tested. If you find anything that a UIlabel support and PHAttributedLabel doesn't, please **fill an issue**. 

# How to install

## Drop-in installation

To use this library, you can simply drage PHAttributedLabel.framework in your Xcode Project. Once this is done, you will have to import the framework like this:

'#import <PHAttributedLabel/PHAttributedLabel.h>'

Since the CoreText.framework is linked to this framework, you won't need to add it to your project for this library to work.

## Source Code installation

If you want to make modification and or put break-point inside PHAttributedLabel class, you will have to use the source code. Simply drag the PHAttributedLabel folder in your Xcode project and import it like you would normally do:

'#import "PHAttributedLabel.h"'

# Sample Code & Documentation

You have a sample code in the Example folder. For the documentation, I have described to the best of my knowledge the 'PHAttributedLabel.h' header file. If you have any other question, you can either ask me via **issues** or [@pothibo](http://www.twitter.com/pothibo) on Twitter.

