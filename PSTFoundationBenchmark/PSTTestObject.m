//
//  PSTTestObject.m
//  PSTFoundationBenchmark
//
//  Created by Peter Steinberger on 05/12/13.
//  Copyright (c) 2013 PSPDFKit GmbH. All rights reserved.
//

#import "PSTTestObject.h"

@implementation PSTTestObject

- (id)copyWithZone:(NSZone *)zone {
    PSTTestObject *copy = [[PSTTestObject alloc] init];
    return copy;
}

@end
