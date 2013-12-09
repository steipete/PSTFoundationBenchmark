//
//  PSTAppDelegate.m
//  PSTFoundationBenchmark
//
//  Created by Peter Steinberger on 01/12/13.
//  Copyright (c) 2013 PSPDFKit GmbH. All rights reserved.
//

#import "PSTAppDelegate.h"
#import "PSTBenchmark.h"

@implementation PSTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [PSTBenchmark new];

    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = UIColor.whiteColor;
    self.window.rootViewController = [UIViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
