//
//  AFKPageFlipper.m
//  AFKPageFlipper
//
//  Created by Marco Tabini on 10-10-12.
//  Copyright 2010 AFK Studio Partnership. All rights reserved.
//

#import "AFKPageFlipper.h"


#pragma mark - UIView helpers

@interface UIView(Extended) 
- (UIImage *) imageByRenderingView;
@end

@implementation UIView(Extended)
- (UIImage *) imageByRenderingView {
	UIGraphicsBeginImageContext(self.bounds.size);
	[self.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return resultingImage;
}
@end


#pragma mark - Private interface

@interface AFKPageFlipper()
@property (nonatomic,retain) UIView *currentView;
@property (nonatomic,retain) UIView *newView;
- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context;
@end


@implementation AFKPageFlipper

#pragma mark - Initialization and memory management

+ (Class)layerClass {
	return [CATransformLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
		UITapGestureRecognizer *tapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)] autorelease];
		UIPanGestureRecognizer *panRecognizer = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)] autorelease];

		[tapRecognizer requireGestureRecognizerToFail:panRecognizer];
		
        [self addGestureRecognizer:tapRecognizer];
		[self addGestureRecognizer:panRecognizer];
    }
    return self;
}

- (void)dealloc {
	self.dataSource = nil;
	self.currentView = nil;
	self.newView = nil;
    [super dealloc];
}


#pragma mark - Frame management

- (void)setFrame:(CGRect)value {
	super.frame = value;
	numberOfPages = [dataSource numberOfPagesForPageFlipper:self];
	if (self.currentPage > numberOfPages) {
		self.currentPage = numberOfPages;
	}	
}


#pragma mark - Flip functionality

- (void)initFlip {
	
	// Create screenshots of view
	
	UIImage *currentImage = [self.currentView imageByRenderingView];
	UIImage *newImage = [self.newView imageByRenderingView];
	
	// Hide existing views
	
	self.currentView.alpha = 0;
	self.newView.alpha = 0;
	
	// Create representational layers
	
	CGRect rect = self.bounds;
	rect.size.width /= 2;
	
	backgroundAnimationLayer = [CALayer layer];
	backgroundAnimationLayer.frame = self.bounds;
	backgroundAnimationLayer.zPosition = -300000;
	
	CALayer *leftLayer = [CALayer layer];
	leftLayer.frame = rect;
	leftLayer.masksToBounds = YES;
	leftLayer.contentsGravity = kCAGravityLeft;
	[backgroundAnimationLayer addSublayer:leftLayer];
	
	rect.origin.x = rect.size.width;
	
	CALayer *rightLayer = [CALayer layer];
	rightLayer.frame = rect;
	rightLayer.masksToBounds = YES;
	rightLayer.contentsGravity = kCAGravityRight;
	[backgroundAnimationLayer addSublayer:rightLayer];
	
	if (flipDirection == AFKPageFlipperDirectionRight) {
		leftLayer.contents = (id) [newImage CGImage];
		rightLayer.contents = (id) [currentImage CGImage];
	} else {
		leftLayer.contents = (id) [currentImage CGImage];
		rightLayer.contents = (id) [newImage CGImage];
	}

	[self.layer addSublayer:backgroundAnimationLayer];
	
	rect.origin.x = 0;
	
	flipAnimationLayer = [CATransformLayer layer];
	flipAnimationLayer.anchorPoint = CGPointMake(1.0, 0.5);
	flipAnimationLayer.frame = rect;
	[self.layer addSublayer:flipAnimationLayer];
	
	CALayer *backLayer = [CALayer layer];
	backLayer.frame = flipAnimationLayer.bounds;
	backLayer.doubleSided = NO;
	backLayer.masksToBounds = YES;
	[flipAnimationLayer addSublayer:backLayer];
	
	CALayer *frontLayer = [CALayer layer];
	frontLayer.frame = flipAnimationLayer.bounds;
	frontLayer.doubleSided = NO;
	frontLayer.masksToBounds = YES;
	frontLayer.transform = CATransform3DMakeRotation(M_PI, 0, 1.0, 0);
	[flipAnimationLayer addSublayer:frontLayer];
	
	if (flipDirection == AFKPageFlipperDirectionRight) {
		backLayer.contents = (id) [currentImage CGImage];
		backLayer.contentsGravity = kCAGravityLeft;
		
		frontLayer.contents = (id) [newImage CGImage];
		frontLayer.contentsGravity = kCAGravityRight;
		
		CATransform3D transform = CATransform3DMakeRotation(0.0, 0.0, 1.0, 0.0);
		transform.m34 = 1.0f / 2500.0f;
		
		flipAnimationLayer.transform = transform;
		
		currentAngle = startFlipAngle = 0;
		endFlipAngle = -M_PI;
	} else {
		backLayer.contentsGravity = kCAGravityLeft;
		backLayer.contents = (id) [newImage CGImage];
		
		frontLayer.contents = (id) [currentImage CGImage];
		frontLayer.contentsGravity = kCAGravityRight;
		
		CATransform3D transform = CATransform3DMakeRotation(-M_PI / 1.1, 0.0, 1.0, 0.0);
		transform.m34 = 1.0f / 2500.0f;
		
		flipAnimationLayer.transform = transform;
		
		currentAngle = startFlipAngle = -M_PI;
		endFlipAngle = 0;
	}
}

- (void)cleanupFlip {
	[backgroundAnimationLayer removeFromSuperlayer];
	[flipAnimationLayer removeFromSuperlayer];

	backgroundAnimationLayer = Nil;
	flipAnimationLayer = Nil;

	animating = NO;

	if (setNewViewOnCompletion) {
		[self.currentView removeFromSuperview];
		self.currentView = self.newView;
		self.newView = Nil;
	} else {
		[self.newView removeFromSuperview];
		self.newView = Nil;
	}

	self.currentView.alpha = 1;
    self.userInteractionEnabled = YES;
}

- (void)setFlipProgress:(float)progress setDelegate:(BOOL)setDelegate animate:(BOOL)animate {
	float newAngle = startFlipAngle + progress * (endFlipAngle - startFlipAngle);
	
	float duration = animate ? 0.5 * fabs((newAngle - currentAngle) / (endFlipAngle - startFlipAngle)) : 0;
	
	currentAngle = newAngle;
	
	CATransform3D endTransform = CATransform3DIdentity;
	endTransform.m34 = 1.0f / 2500.0f;
	endTransform = CATransform3DRotate(endTransform, newAngle, 0.0, 1.0, 0.0);	
	
	[flipAnimationLayer removeAllAnimations];
    self.userInteractionEnabled = NO;

	[CATransaction begin];
	[CATransaction setAnimationDuration:duration];
	
	flipAnimationLayer.transform = endTransform;
	
	[CATransaction commit];

	if (setDelegate) {
		[self performSelector:@selector(cleanupFlip) withObject:Nil afterDelay:duration];
	}
}

- (void)flipPage {
	[self setFlipProgress:1.0 setDelegate:YES animate:YES];
}

// determines flip direction, set's the new page as current, assigns newView
// returns if changing to this page number is valid (not already on page)
- (BOOL)prepareChangeCurrentPage:(NSInteger)newPage {
	if (newPage == currentPage) {
		return FALSE;
	}

	flipDirection = newPage < currentPage ? AFKPageFlipperDirectionRight : AFKPageFlipperDirectionLeft;	
	currentPage = newPage;

	self.newView = [self.dataSource viewForPage:newPage inFlipper:self];
	[self addSubview:self.newView];
	return TRUE;
}

- (void)changeCurrentPage:(NSInteger)page animated:(BOOL)animated {
	if (![self prepareChangeCurrentPage:page]) {
		return;
	}

	setNewViewOnCompletion = YES;
	animating = YES;

	if (animated) {
		[self initFlip];
		[self performSelector:@selector(flipPage) withObject:Nil afterDelay:0.001];
	} else {
		[self animationDidStop:nil finished:[NSNumber numberWithBool:NO] context:nil];
	}
}


#pragma mark - Animation management

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	[self cleanupFlip];
}


#pragma mark - Properties

// setting the current page, by default just fades in (no flipping)
// when current page is set via property (page 1) - fade in
- (void)setCurrentPage:(NSInteger)value {
	if (![self prepareChangeCurrentPage:value]) {
		return;
	}
	
	setNewViewOnCompletion = YES;
	animating = YES;
	
	self.newView.alpha = 0;
	
	[UIView beginAnimations:@"" context:Nil];
	[UIView setAnimationDuration:0.5];
	[UIView setAnimationDelegate:self];
	[UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
	self.newView.alpha = 1;
	[UIView commitAnimations];
}

- (void)setDataSource:(NSObject <AFKPageFlipperDataSource>*)value {
    if (dataSource != value) {
        dataSource = value;
        numberOfPages = [dataSource numberOfPagesForPageFlipper:self];
        self.currentPage = 1;
    }
}

- (void)setDisabled:(BOOL)value {
	disabled = value;
	self.userInteractionEnabled = !value;
	for (UIGestureRecognizer *recognizer in self.gestureRecognizers) {
		recognizer.enabled = !value;
	}
}


#pragma mark - Touch management

- (void)tapped:(UITapGestureRecognizer *)recognizer {
	if (animating || self.disabled) {
		return;
	}

	if (recognizer.state == UIGestureRecognizerStateRecognized) {
		NSInteger newPage;
		
		if ([recognizer locationInView:self].x < (self.bounds.size.width - self.bounds.origin.x) / 2) {
			newPage = MAX(1, self.currentPage - 1);
		} else {
			newPage = MIN(self.currentPage + 1, numberOfPages);
		}

        [self changeCurrentPage:newPage animated:YES];
	}
}

- (void)panned:(UIPanGestureRecognizer *)recognizer {
	static BOOL hasFailed;
	static BOOL initialized;
	static NSInteger oldPage;
	float translation = [recognizer translationInView:self].x;
	float progress = translation / self.bounds.size.width;

	if (flipDirection == AFKPageFlipperDirectionLeft) {
		progress = MIN(progress, 0);
	} else {
		progress = MAX(progress, 0);
	}

	switch (recognizer.state) {
		case UIGestureRecognizerStateBegan:
			hasFailed = FALSE;
			initialized = FALSE;
			animating = NO;
			setNewViewOnCompletion = NO;
			break;

		case UIGestureRecognizerStateChanged:
			if (hasFailed) {
				return;
			}

			if (!initialized) {
				oldPage = self.currentPage;
				
				if (translation > 0) {
					if (self.currentPage > 1) {
						[self prepareChangeCurrentPage:self.currentPage - 1];
					} else {
						hasFailed = TRUE;
						return;
					}
				} else {
					if (self.currentPage < numberOfPages - 1) {
						[self prepareChangeCurrentPage:self.currentPage + 1];
					} else {
						hasFailed = TRUE;
						return;
					}
				}

				hasFailed = NO;
				initialized = TRUE;
				animating = YES;
				setNewViewOnCompletion = NO;

				[self initFlip];
			}

			[self setFlipProgress:fabs(progress) setDelegate:NO animate:NO];
			break;

		case UIGestureRecognizerStateFailed:
			[self setFlipProgress:0.0 setDelegate:YES animate:YES];
			currentPage = oldPage;
			break;

		case UIGestureRecognizerStateRecognized:
			if (hasFailed) {
				[self setFlipProgress:0.0 setDelegate:YES animate:YES];
				currentPage = oldPage;
				return;
			}

			if (fabs((translation + [recognizer velocityInView:self].x / 4) / self.bounds.size.width) > 0.5) {
				setNewViewOnCompletion = YES;
				[self setFlipProgress:1.0 setDelegate:YES animate:YES];
			} else {
				[self setFlipProgress:0.0 setDelegate:YES animate:YES];
				currentPage = oldPage;
			}
			break;

        default:
            break;
	}
}




@synthesize currentView;
@synthesize newView;
@synthesize currentPage;
@synthesize dataSource;
@synthesize disabled;
@end
