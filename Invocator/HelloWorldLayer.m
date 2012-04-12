//
//  HelloWorldLayer.m
//  Invocator
//
//  Created by Toru Hisai on 12/04/12.
//  Copyright Kronecker's Delta Studio 2012年. All rights reserved.
//


// Import the interfaces
#import "HelloWorldLayer.h"

// HelloWorldLayer implementation
@implementation HelloWorldLayer

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorldLayer *layer = [HelloWorldLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

// on "init" you need to initialize your instance
-(id) init
{
	// always call "super" init
	// Apple recommends to re-assign "self" with the "super" return value
	if( (self=[super init])) {
		
		// create and initialize a Label
		CCLabelTTF *label = [CCLabelTTF labelWithString:@"Hello World" fontName:@"Marker Felt" fontSize:64];

		// ask director the the window size
		CGSize size = [[CCDirector sharedDirector] winSize];
	
		// position the label on the center of the screen
		label.position =  ccp( size.width /2 , size.height/2 );
		
		// add the label as a child to this Layer
		[self addChild: label];
	}
    
    NSString *str = @"Hoge Fuga";
    SEL sel = sel_getUid("characterAtIndex:");
    NSMethodSignature *sig = [str methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    NSUInteger numarg = [sig numberOfArguments];
    NSLog(@"Number of arguments = %d", numarg);
    
    for (int i = 0; i < numarg; i++) {
        const char *t = [sig getArgumentTypeAtIndex:i];
        NSLog(@"arg %d: %s", i, t);
    }

    [inv setTarget:str];
    [inv setSelector:sel];
    NSUInteger arg1 = 5;
    [inv setArgument:&arg1 atIndex:2];
    [inv invoke];
    
    NSUInteger len = [[inv methodSignature] methodReturnLength];
    const char *rettype = [sig methodReturnType];
    NSLog(@"ret type = %s", rettype);
    void *buffer = malloc(len);
    [inv getReturnValue:buffer];
    NSLog(@"ret = %c", *(unichar*)buffer);
    
	return self;
}

// on "dealloc" you need to release all your retained objects
- (void) dealloc
{
	// in case you have something to dealloc, do it in this method
	// in this particular example nothing needs to be released.
	// cocos2d will automatically release all the children (Label)
	
	// don't forget to call "super dealloc"
	[super dealloc];
}
@end
