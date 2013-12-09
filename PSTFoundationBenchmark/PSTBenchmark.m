//
//  PSTBenchmark.m
//  PSTFoundationBenchmark
//
//  Created by Peter Steinberger on 01/12/13.
//  Copyright (c) 2013 PSPDFKit GmbH. All rights reserved.
//

#import "PSTBenchmark.h"
#import "PSTTestObject.h"
#import "PSPDFThreadSafeMutableDictionary.h"
#include <mach/mach_time.h>
#import <stdlib.h>

@implementation PSTBenchmark

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (id)init {
    if (self = [super init]) {
        [self startBenchmark];
    }
    return self;
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Main Benchmark

static CFStringRef CF_RETURNS_NOT_RETAINED PSPDFRawKeyDescription(const void *value) {return (__bridge CFStringRef)[NSString stringWithFormat:@"%c", (UniChar)value];}
static Boolean PSPDFRawEqual(const void *val1, const void *val2) {return val1 == val2; }
// Multiplying by 31 (prime) gives us a lot better hash, resulting in a 4x performance increase.
static CFHashCode PSPDFRawHash(const void *value) { return (CFHashCode)value * 31;}

const CFDictionaryKeyCallBacks PSPDFRawKeyDictionaryCallbacks = {0, NULL, NULL, PSPDFRawKeyDescription, PSPDFRawEqual, PSPDFRawHash };

static int count = 0;
NSInteger alphabeticSort(id string1, id string2, void *reverse)
{
    count++;

    if (*(BOOL *)reverse == YES) {
        return [string2 localizedCaseInsensitiveCompare:string1];
    }
    return [string1 localizedCaseInsensitiveCompare:string2];
}


NSInteger localizedCaseInsensitiveCompareSort(id string1, id string2, void *context) {
    return [string1 localizedCaseInsensitiveCompare:string2];
}


- (void)startBenchmark {
    [self testIndexSetAndSetPerformance];
    [self cfDictionaryKeyCopyTest];

    @autoreleasepool {
        [self performanceOfInitWithCountOnSet];
    }
    @autoreleasepool {
        [self performanceOfInitWithCountOnArray];
    }

    @autoreleasepool {
        [self filteringArrayBenchmark];
    }
    @autoreleasepool {
        [self sortingBenchmark];
    }

    @autoreleasepool {
        [self arrayInsertionTimes];
    }

    @autoreleasepool {
        [self performanceOfInitWithCountOnDictionary];
    }

    @autoreleasepool {
        [self filteringDictionaryBenchmark];
    }

    // Test adding time
    [self arrayBenchmark];
}

- (void)arrayBenchmark {
    [@[@(10000), @(100000), @(1000000), @(10000000), @(20000000)] enumerateObjectsUsingBlock:^(NSNumber *entriesNumber, NSUInteger runCount, BOOL *stop) {
        NSUInteger entries = entriesNumber.unsignedIntegerValue;
        printf("Operation Count: %g [run %tu]", (double)entries, runCount+1);

        NSMutableSet *randomAccessNumbers = [NSMutableSet set];
        for (NSUInteger accessIdx = 0; accessIdx < entries/100; accessIdx++) {
            [randomAccessNumbers addObject:@(arc4random_uniform((u_int32_t)entries))];
        }

        const NSUInteger skipCount = 1;
        double dict_add_time = 0, dict_ts_add_time = 0, cfDict_add_time = 0, cache_add_time = 0, array_add_time = 0, cfArray_add_time = 0, pointerArray_add_time = 0, maptable_add_time = 0, ordered_set_add_time = 0, set_add_time = 0, hashtable_add_time = 0;
        double dict_rac_time = 0, dict_ts_rac_time = 0, cfDict_rac_time = 0, cache_rac_time = 0, array_rac_time = 0, cfArray_rac_time = 0, pointerArray_rac_time = 0, maptable_rac_time = 0, ordered_set_rac_time = 0, set_rac_time = 0, hashtable_rac_time = 0;
        double set_contains_time = 0, hashtable_contains_time = 0, set_iteration_time = 0, hashtable_iteration_time = 0;

        @autoreleasepool {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            dict_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                    dictionary[@(idx)] = PSPDFEntryForIDX(idx);
                }
            });
            dict_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused id object = dictionary[number];
                }];
            });
        }

        @autoreleasepool {
            NSMutableDictionary *dictionary = [PSPDFThreadSafeMutableDictionary dictionary];
            dict_ts_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                    dictionary[@(idx)] = PSPDFEntryForIDX(idx);
                }
            });
            dict_ts_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused id object = dictionary[number];
                }];
            });
        }

        @autoreleasepool {
            CFMutableDictionaryRef dictionaryRef = CFDictionaryCreateMutable(NULL, 0, &PSPDFRawKeyDictionaryCallbacks, &kCFTypeDictionaryValueCallBacks);
            cfDict_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                    CFDictionarySetValue(dictionaryRef, (void *)idx, (__bridge const void *)(PSPDFEntryForIDX(idx)));
                }
            });
            cfDict_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused const void *object = CFDictionaryGetValue(dictionaryRef, (void *)idx);
                }];
            });
        }

        @autoreleasepool {
            NSCache *cache = [NSCache new];
            cache_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                    [cache setObject:PSPDFEntryForIDX(idx) forKey:@(idx)];
                }
            });
            cache_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused id object = [cache objectForKey:@(idx)];
                }];
            });
        }

        // Needs to be filled with nil - can't have NULL entries.
        @autoreleasepool {
            NSMutableArray *array = [NSMutableArray array];
            NSNull *null = NSNull.null;
            array_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx++) {
                    [array addObject:null];
                }
                for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                    array[idx] = PSPDFEntryForIDX(idx);
                }
            });
            array_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused id object = array[idx];
                }];
            });
        }

        @autoreleasepool {
            CFMutableArrayRef arrayRef = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
            cfArray_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx++) {
                    CFArrayAppendValue(arrayRef, kCFNull);
                }
                for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                    CFArraySetValueAtIndex(arrayRef, idx, (__bridge const void *)(PSPDFEntryForIDX(idx)));
                }
            });
            cfArray_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused id object = CFArrayGetValueAtIndex(arrayRef, idx);
                }];
            });
        }

        @autoreleasepool {
            if (entries < 1e4) {
                NSPointerArray *pointerArray = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsStrongMemory];
                [pointerArray setCount:entries];
                pointerArray_add_time = PSPDFPerformAndTrackTime(^{
                    for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                        [pointerArray insertPointer:(__bridge void *)(PSPDFEntryForIDX(idx)) atIndex:idx];
                    }
                });
                pointerArray_rac_time = PSPDFPerformAndTrackTime(^{
                    [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                        __unused NSUInteger idx = number.unsignedIntegerValue;
                        __unused void *object = [pointerArray pointerAtIndex:idx];
                    }];
                });
            }
        }

        @autoreleasepool {
            NSMapTable *mapTable = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsObjectPersonality valueOptions:NSPointerFunctionsObjectPersonality capacity:0];
            maptable_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx+=skipCount) {
                    [mapTable setObject:PSPDFEntryForIDX(idx) forKey:@(idx)];
                }
            });
            maptable_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused id object = [mapTable objectForKey:number];
                }];
            });
        }

        @autoreleasepool {
            NSMutableOrderedSet *orderedSet = [NSMutableOrderedSet orderedSet];
            ordered_set_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx++) {
                    [orderedSet addObject:PSPDFEntryForIDX(idx)];
                }
            });
            ordered_set_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    __unused id object = [orderedSet objectAtIndex:idx];
                }];
            });
        }

        @autoreleasepool {
            NSMutableSet *set = [NSMutableSet set];
            set_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx++) {
                    [set addObject:PSPDFEntryForIDX(idx)];
                }
            });
            set_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    [set anyObject];
                }];
            });
            set_contains_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    [set containsObject:number];
                }];
            });
            set_iteration_time = PSPDFPerformAndTrackTime(^{
                for (NSString *obj in set) {
                    // nothing
                }
            });

        }

        @autoreleasepool {
            NSHashTable *hashTable = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
            hashtable_add_time = PSPDFPerformAndTrackTime(^{
                for (NSUInteger idx = 0; idx < entries; idx++) {
                    [hashTable addObject:PSPDFEntryForIDX(idx)];
                }
            });
            hashtable_rac_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger idx = number.unsignedIntegerValue;
                    [hashTable anyObject];
                }];
            });
            hashtable_contains_time = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    [hashTable containsObject:number];
                }];
            });
            hashtable_iteration_time = PSPDFPerformAndTrackTime(^{
                for (NSString *obj in hashTable) {
                    // nothing
                }
            });
        }

        printf("\n");
        if (dict_add_time)         printf("Adding Elements to NSMutableDictionary: %f [ms]\n", dict_add_time/1E6);
        if (dict_ts_add_time)      printf("Adding Elements to PSPDFThreadSafeMutableDictionary: %f [ms]\n", dict_ts_add_time/1E6);
        if (cfDict_add_time)       printf("Adding Elements to CFMutableDictionary: %f [ms]\n", cfDict_add_time/1E6);
        if (cache_add_time)        printf("Adding Elements to NSCache:             %f [ms]\n", cache_add_time/1E6);
        if (array_add_time)        printf("Adding Elements to NSMutableArray:      %f [ms]\n", array_add_time/1E6);
        if (cfArray_add_time)      printf("Adding Elements to CFMutableArray:      %f [ms]\n", cfArray_add_time/1E6);
        if (ordered_set_add_time)  printf("Adding Elements to NSMutableOrderedSet: %f [ms]\n", ordered_set_add_time/1E6);
        if (set_add_time)          printf("Adding Elements to NSMutableSet:        %f [ms]\n", set_add_time/1E6);
        if (hashtable_add_time)    printf("Adding Elements to NSHashTable:         %f [ms]\n", hashtable_add_time/1E6);
        if (pointerArray_add_time) printf("Adding Elements to NSPointerArray:      %f [ms]\n", pointerArray_add_time/1E6);
        if (maptable_add_time)     printf("Adding Elements to NSMapTable:          %f [ms]\n", maptable_add_time/1E6);
        printf("\n");
        if (dict_rac_time)         printf("Random Access for  NSMutableDictionary: %f [ms]\n", dict_rac_time/1E6);
        if (dict_ts_rac_time)      printf("Random Access for  PSPDFThreadSafeMutableDictionary: %f [ms]\n", dict_ts_rac_time/1E6);
        if (cfDict_rac_time)       printf("Random Access for  CFMutableDictionary: %f [ms]\n", cfDict_rac_time/1E6);
        if (cache_rac_time)        printf("Random Access for  NSCache:             %f [ms]\n", cache_rac_time/1E6);
        if (array_rac_time)        printf("Random Access for  NSMutableArray:      %f [ms]\n", array_rac_time/1E6);
        if (cfArray_rac_time)      printf("Random Access for  CFMutableArray:      %f [ms]\n", cfArray_rac_time/1E6);
        if (ordered_set_rac_time)  printf("Random Access for  NSMutableOrderedSet: %f [ms]\n", ordered_set_rac_time/1E6);
        if (set_rac_time)          printf("Random Access for  NSMutableSet:        %f [ms]\n", set_rac_time/1E6);
        if (hashtable_rac_time)    printf("Random Access for  NSHashTable:         %f [ms]\n", hashtable_rac_time/1E6);
        if (pointerArray_rac_time) printf("Random Access for  NSPointerArray:      %f [ms]\n", pointerArray_rac_time/1E6);
        if (maptable_rac_time)     printf("Random Access for  NSMapTable:          %f [ms]\n", maptable_rac_time/1E6);
        printf("\n");
        if (set_contains_time)     printf("containsObject: for NSMutableSet:      %f [ms]\n", set_contains_time/1E6);
        if (hashtable_contains_time) printf("containsObject: for NSHashTable:       %f [ms]\n", hashtable_contains_time/1E6);
        if (set_iteration_time)     printf("NSFastEnumeration for NSMutableSet:     %f [ms]\n", set_iteration_time/1E6);
        if (hashtable_iteration_time) printf("NSFastEnumeration for NSHashTable:    %f [ms]\n", hashtable_iteration_time/1E6);
        printf("\n");
    }];
}

- (void)testIndexSetAndSetPerformance {
    [@[@(10000), @(100000), @(1000000), @(10000000), @(20000000)] enumerateObjectsUsingBlock:^(NSNumber *entriesNumber, NSUInteger runCount, BOOL *stop) {
        @autoreleasepool {
            NSUInteger entries = entriesNumber.unsignedIntegerValue;
            NSLog(@"Operation Count: %g [run %tu]", (double)entries, runCount+1);

            NSMutableSet *randomAccessNumbers = [NSMutableSet set];
            for (NSUInteger accessIdx = 0; accessIdx < entries/100; accessIdx++) {
                [randomAccessNumbers addObject:@(arc4random_uniform((u_int32_t)entries))];
            }

            NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
            double indexSetPerf = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    [indexSet addIndex:number.unsignedIntegerValue];
                }];
            });

            double setIndexRAC = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    [indexSet containsIndex:number.unsignedIntegerValue];
                }];
            });

            NSMutableSet *set = [NSMutableSet set];
            double setPerf = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger index = number.unsignedIntegerValue;
                    [set addObject:number];
                }];
            });

            double setRAC = PSPDFPerformAndTrackTime(^{
                [randomAccessNumbers enumerateObjectsUsingBlock:^(NSNumber *number, BOOL *stop) {
                    __unused NSUInteger index = number.unsignedIntegerValue;
                    [set containsObject:number];
                }];
            });

            NSLog(@"Adding Objects: NSIndexSet: %f [ms]. NSSet: %f [ms]", indexSetPerf/1E6, setPerf/1E6);
            NSLog(@"Random Access:  NSIndexSet: %f [ms]. NSSet: %f [ms]", setIndexRAC/1E6, setRAC/1E6);
        }
    }];
}

- (void)sortingBenchmark {
    // Create random array
    NSUInteger const numberOfEntries = 1000000;
    NSMutableArray *randomArray = [NSMutableArray array];
    for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
        [randomArray addObject:[NSString stringWithFormat:@"%tu", arc4random_uniform(500000)]];
    }

    double sort1 = PSPDFPerformAndTrackTime(^{
        [randomArray sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    });

    double sort2 = PSPDFPerformAndTrackTime(^{
        [randomArray sortedArrayUsingFunction:localizedCaseInsensitiveCompareSort context:NULL];
    });

    NSComparator caseInsensitiveComparator = ^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj1 localizedCaseInsensitiveCompare:obj2];
    };

    double sort3 = PSPDFPerformAndTrackTime(^{
        [randomArray sortedArrayWithOptions:NSSortConcurrent usingComparator:caseInsensitiveComparator];
    });

    NSLog(@"Sorting %tu elements. selector: %.2f[ms] function: %.2f[ms] block: %.2f[ms].", randomArray.count, sort1/1E6, sort2/1E6, sort3/1E6);

    NSArray *sortedArray = [randomArray sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSUInteger const searchNumberOfEntries = numberOfEntries/1000;

    double contains1 = PSPDFPerformAndTrackTime(^{
        for (NSUInteger idx = 0; idx < searchNumberOfEntries; idx++) {
            [sortedArray indexOfObject:randomArray[idx]];
        }
    });

    double contains2 = PSPDFPerformAndTrackTime(^{
        for (NSUInteger idx = 0; idx < searchNumberOfEntries; idx++) {
            [sortedArray indexOfObject:randomArray[idx] inSortedRange:NSMakeRange(0, numberOfEntries) options:NSBinarySearchingFirstEqual usingComparator:caseInsensitiveComparator];
        }
    });

    NSOrderedSet *orderedSet = [NSOrderedSet orderedSetWithArray:sortedArray];
    double contains3 = PSPDFPerformAndTrackTime(^{
        for (NSUInteger idx = 0; idx < searchNumberOfEntries; idx++) {
            [orderedSet indexOfObject:randomArray[idx]];
        }
    });

    NSLog(@"Time to search for %tu entries. Linear: %.2f[ms]. Binary: %.2f[ms] NSOrderedSet: %.2f[ms]", searchNumberOfEntries, contains1/1E6, contains2/1E6, contains3/1E6);
}

- (void)filteringArrayBenchmark {
    // Create random array
    NSUInteger const numberOfEntries = 10000000;
    NSMutableArray *randomArray = [NSMutableArray array];
    for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
        [randomArray addObject:[NSString stringWithFormat:@"%tu", arc4random_uniform(500000)]];
    }

    BOOL (^testObj)(id obj) = ^BOOL(id obj) {
        return [obj integerValue] < 10;
    };

    // warning: typed in mail client
    double filter1 = PSPDFPerformAndTrackTime(^{
        NSIndexSet *indexes = [randomArray indexesOfObjectsWithOptions:0 passingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return testObj(obj);
        }];
        __unused NSArray *filteredArray1 = [randomArray objectsAtIndexes:indexes];
    });

    double filter1_rec = PSPDFPerformAndTrackTime(^{
        NSIndexSet *indexes = [randomArray indexesOfObjectsWithOptions:NSEnumerationConcurrent passingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return testObj(obj);
        }];
        __unused NSArray *filteredArray1 = [randomArray objectsAtIndexes:indexes];
    });

    double filter2 = PSPDFPerformAndTrackTime(^{
        __unused NSArray *filteredArray2 = [randomArray filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
            return testObj(obj);
        }]];
    });

    double filter3 = PSPDFPerformAndTrackTime(^{
        NSMutableArray *mutableArray = [NSMutableArray array];
        [randomArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if (testObj(obj)) {
                [mutableArray addObject:obj];
            }
        }];
        __unused NSArray *filteredArray3 = [mutableArray copy];
    });

    double filter4 = PSPDFPerformAndTrackTime(^{
        NSMutableArray *mutableArray = [NSMutableArray array];
        for (id obj in randomArray) {
            if (testObj(obj)) {
                [mutableArray addObject:obj];
            }
        }
        __unused NSArray *filteredArray4 = [mutableArray copy];
    });

    double filter5 = PSPDFPerformAndTrackTime(^{
        NSMutableArray *mutableArray = [NSMutableArray array];
        NSEnumerator *enumerator = [randomArray objectEnumerator];
        id obj = nil;
        while ((obj = [enumerator nextObject]) != nil) {
            if (testObj(obj)) {
                [mutableArray addObject:obj];
            }
        }
        __unused NSArray *filteredArray5 = [mutableArray copy];
    });

    double filter6 = PSPDFPerformAndTrackTime(^{
        NSMutableArray *mutableArray = [NSMutableArray array];
        for (NSUInteger idx = 0; idx < randomArray.count; idx++) {
            id obj = randomArray[idx];
            if (testObj(obj)) {
                [mutableArray addObject:obj];
            }
        }
        __unused NSArray *filteredArray6 = [mutableArray copy];
    });

    NSLog(@"Filtering %tu elements. indexesOfObjects: %.5f[ms] indexesOfObjects-recursive: %.5f[ms] filteredArrayUsingPredicate: %.5f[ms] block: %.5f[ms] classic: %.5f[ms] NSEnumerator: %.5f[ms] objectAtIndex: %.5f[ms].", randomArray.count, filter1/1E6, filter1_rec/1E6, filter2/1E6, filter3/1E6, filter4/1E6, filter5/1E6, filter6/1E6);
}

- (void)filteringDictionaryBenchmark {
    @autoreleasepool {
        // Create random dictionary
        NSUInteger const numberOfEntries = 1000000;
        NSMutableDictionary *randomDict = [NSMutableDictionary dictionary];
        for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
            randomDict[@(idx)] = [NSString stringWithFormat:@"%tu", arc4random_uniform(500000)];
        }

        BOOL (^testObj)(id obj) = ^BOOL(id obj) {
            return [obj integerValue] < 10;
        };

        double filter1 = PSPDFPerformAndTrackTimeMultiple(^{
            NSSet *matchingKeys = [randomDict keysOfEntriesWithOptions:0 passingTest:^BOOL(id key, id obj, BOOL *stop) {
                return testObj(obj);
            }];
            NSArray *keys = matchingKeys.allObjects;
            NSArray *values = [randomDict objectsForKeys:keys notFoundMarker:NSNull.null];
            __unused NSDictionary *filteredDictionary = [NSDictionary dictionaryWithObjects:values forKeys:keys];
        }, 3);

        double filter2 = PSPDFPerformAndTrackTimeMultiple(^{
            NSArray *keys = [randomDict keysOfEntriesWithOptions:NSEnumerationConcurrent passingTest:^BOOL(id key, id obj, BOOL *stop) {
                return testObj(obj);
            }].allObjects;
            __unused NSDictionary *filteredDictionary2 = [NSDictionary dictionaryWithObjects:[randomDict objectsForKeys:keys notFoundMarker:NSNull.null] forKeys:keys];
        }, 3);

        double filter3 = PSPDFPerformAndTrackTimeMultiple(^{
            NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
            [randomDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (testObj(obj)) {
                    mutableDictionary[key] = obj;
                }
            }];
            __unused NSDictionary *filteredDictionary3 = [mutableDictionary copy];
        }, 3);

        double filter4 = PSPDFPerformAndTrackTimeMultiple(^{
            NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
            for (id key in randomDict) {
                id obj = randomDict[key];
                if (testObj(obj)) {
                    mutableDictionary[key] = obj;
                }
            }
            __unused NSDictionary *filteredDictionary4 = [mutableDictionary copy];
        }, 3);

        double filter5 = PSPDFPerformAndTrackTimeMultiple(^{
            NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
            id __unsafe_unretained *objects = (id __unsafe_unretained *)malloc(sizeof(id) * numberOfEntries);
            id __unsafe_unretained *keys = (id __unsafe_unretained *)(malloc(sizeof(id) * numberOfEntries));
            [randomDict getObjects:objects andKeys:keys];
            for (int i = 0; i < numberOfEntries; i++) {
                id obj = objects[i];
                id key = keys[i];
                if (testObj(obj)) {
                    mutableDictionary[key] = obj;
                }
            }
            free(objects);
            free(keys);
            __unused NSDictionary *filteredDictionary5 = [mutableDictionary copy];
        }, 3);

        double filter6 = PSPDFPerformAndTrackTimeMultiple(^{
            NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
            NSEnumerator *enumerator = [randomDict keyEnumerator];
            id key = nil;
            while ((key = [enumerator nextObject]) != nil) {
                id obj = randomDict[key];
                if (testObj(obj)) {
                    mutableDictionary[key] = obj;
                }
            }
            __unused NSDictionary *filteredDictionary6 = [mutableDictionary copy];
        }, 3);

        NSLog(@"Filtering %tu elements. keysOfEntriesWithOptions: %.2f[ms] keysOfEntriesWithOptions (concurrent): %.2f[ms] enumerateKeysAndObjectsUsingBlock: %.2f[ms] NSFastEnumeration: %.2f[ms] getObjects: %.2f[ms] NSEnumeration: %.2f[ms].", randomDict.count, filter1/1E6, filter2/1E6, filter3/1E6, filter4/1E6, filter5/1E6, filter6/1E6);
    }
}

- (void)performanceOfInitWithCountOnArray {
    NSUInteger const numberOfEntries = 10000000;

    double with_count = PSPDFPerformAndTrackTimeMultiple(^{
        NSMutableArray *randomArray = [NSMutableArray arrayWithCapacity:numberOfEntries];
        for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
            [randomArray addObject:NSNull.null];
        }
    }, 5);

    double no_count = PSPDFPerformAndTrackTimeMultiple(^{
        NSMutableArray *randomArray = [NSMutableArray array];
        for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
            [randomArray addObject:NSNull.null];
        }
    }, 5);

    NSLog(@"Adding %tu elements to NSArray. no count %.2f[ms] with count: %.2f[ms].", numberOfEntries, no_count/1E6, with_count/1E6);
}

- (void)performanceOfInitWithCountOnDictionary {
    NSUInteger const numberOfEntries = 10000000;

    double no_count = PSPDFPerformAndTrackTimeMultiple(^{
        NSMutableDictionary *randomDict = [NSMutableDictionary dictionary];
        for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
            randomDict[@(idx)] = NSNull.null;
        }
    }, 5);

    double with_count = PSPDFPerformAndTrackTimeMultiple(^{
        NSMutableDictionary *randomDict = [NSMutableDictionary dictionaryWithCapacity:numberOfEntries];
        for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
            randomDict[@(idx)] = NSNull.null;
        }
    }, 5);

    NSLog(@"Adding %tu elements to NSDictionary. no count %.2f[ms] with count: %.2f[ms].", numberOfEntries, no_count/1E6, with_count/1E6);
}

- (void)performanceOfInitWithCountOnSet {
    NSUInteger const numberOfEntries = 1000000;

    // Create first set so that we don't have any performance differences from already created strings etc
    NSMutableSet *randomSet = [NSMutableSet setWithCapacity:numberOfEntries];
    for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
        [randomSet addObject:PSPDFEntryForIDX(idx)];
    }

    double no_count = PSPDFPerformAndTrackTimeMultiple(^{
        NSMutableSet *randomSet = [NSMutableSet set];
        for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
            [randomSet addObject:PSPDFEntryForIDX(idx)];
        }
    }, 5);

    double with_count = PSPDFPerformAndTrackTimeMultiple(^{
        NSMutableSet *randomSet = [NSMutableSet setWithCapacity:numberOfEntries];
        for (NSUInteger idx = 0; idx < numberOfEntries; idx++) {
            [randomSet addObject:PSPDFEntryForIDX(idx)];
        }
    }, 5);

    NSLog(@"Adding %tu elements to NSSet. no count %.2f[ms] with count: %.2f[ms].", numberOfEntries, no_count/1E6, with_count/1E6);
}


- (void)sharedKeyTest {
    id sharedKeySet = [NSDictionary sharedKeySetForKeys:@[@1, @2, @3]]; // returns NSSharedKeySet
    NSMutableDictionary *test = [NSMutableDictionary dictionaryWithSharedKeySet:sharedKeySet];
    test[@4] = @"Works";
    NSDictionary *immTest = [test copy];
    NSParameterAssert(immTest.count == 1);
    ((NSMutableDictionary *)immTest)[@5] = @"Adding object to an 'immutable' collection.";
    NSParameterAssert(immTest.count == 2);
}

- (void)cfDictionaryKeyCopyTest {
    CFMutableDictionaryRef dictRef = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    PSTTestObject *obj = [PSTTestObject new];

    // Setting via Core Foundation does not invoke copyWithZone: on the object.
    CFDictionarySetValue(dictRef, (__bridge const void *)(obj), CFSTR("Test1"));

    // Casting to NSMutableDictionary will call copy.
    ((__bridge NSMutableDictionary *)dictRef)[obj] = @"test2";

    CFRelease(dictRef);

    // Will always copy keys.
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionary];
    CFDictionarySetValue((__bridge CFMutableDictionaryRef)(mutableDict), (__bridge const void *)(obj), CFSTR("Test3"));
    mutableDict[obj] = @"Test4";
}

- (void)arrayInsertionTimes {
    NSMutableArray *insertAtEndTimes = [NSMutableArray array];
    NSMutableArray *insertAtBeginningTimes = [NSMutableArray array];
    NSMutableArray *insertRandomTimes = [NSMutableArray array];

    NSMutableArray *deleteBeginning = [NSMutableArray array];
    NSMutableArray *deleteEnd = [NSMutableArray array];
    NSMutableArray *deleteRandom = [NSMutableArray array];

    const NSUInteger numberOfRuns = 5000;
    const NSUInteger addsPerRun   = 1000;

    @autoreleasepool {
        NSMutableArray *array = [NSMutableArray array];
        for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
            double add_time = PSPDFPerformAndTrackTimeMultiple(^{
                [array addObject:PSPDFEntryForIDX(idx)];
            }, addsPerRun);
            [insertAtEndTimes addObject:@(add_time)];
        }
    }

    @autoreleasepool {
        NSMutableArray *array = [NSMutableArray array];
        for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
            double add_time = PSPDFPerformAndTrackTimeMultiple(^{
                [array insertObject:PSPDFEntryForIDX(idx) atIndex:0];
            }, addsPerRun);
            [insertAtBeginningTimes addObject:@(add_time)];
        }
    }

    @autoreleasepool {
        NSMutableArray *array = [NSMutableArray array];
        for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
            double add_time = PSPDFPerformAndTrackTimeMultiple(^{
                [array insertObject:PSPDFEntryForIDX(idx) atIndex:(NSUInteger)arc4random_uniform((u_int32_t)array.count)];
            }, addsPerRun);
            [insertRandomTimes addObject:@(add_time)];
        }
    }

    // Deletion Tests
    @autoreleasepool {
        // Prepare array
        NSMutableArray *array = [NSMutableArray array];
        for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
            for (NSUInteger subIdx = 0; subIdx < addsPerRun; subIdx++) {
                [array addObject:PSPDFEntryForIDX(idx)];
            }
        }

        @autoreleasepool {
            NSMutableArray *deleteBeginningArray = [array mutableCopy];
            for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
                double add_time = PSPDFPerformAndTrackTimeMultiple(^{
                    [deleteBeginningArray removeObjectAtIndex:0];
                }, addsPerRun);
                [deleteBeginning addObject:@(add_time)];
            }
        }

        @autoreleasepool {
            NSMutableArray *deleteEndArray = [array mutableCopy];
            for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
                double add_time = PSPDFPerformAndTrackTimeMultiple(^{
                    [deleteEndArray removeLastObject];
                }, addsPerRun);
                [deleteEnd addObject:@(add_time)];
            }
        }

        @autoreleasepool {
            NSMutableArray *deleteRandomArray = [array mutableCopy];
            for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
                double add_time = PSPDFPerformAndTrackTimeMultiple(^{
                    [deleteRandomArray removeObjectAtIndex:(NSUInteger)arc4random_uniform((u_int32_t)deleteRandomArray.count)];
                }, addsPerRun);
                [deleteRandom addObject:@(add_time)];
            }
        }
    }

    // Write CSV
    NSMutableString *csvExport = [NSMutableString string];
    [csvExport appendString:@"Insert at beginning, Insert at end, Insert random, Delete beginning, Delete end, Delete random\n"];
    for (NSUInteger idx = 0; idx < numberOfRuns; idx++) {
        [csvExport appendFormat:@"%.2f, %.2f, %.2f, %.2f, %.2f, %.2f\n", [insertAtBeginningTimes[idx] floatValue], [insertAtEndTimes[idx] floatValue], [insertRandomTimes[idx] floatValue], [deleteBeginning[numberOfRuns-idx-1] floatValue], [deleteEnd[numberOfRuns-idx-1] floatValue], [deleteRandom[numberOfRuns-idx-1] floatValue]];
    }

    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (![csvExport writeToFile:[documentPath stringByAppendingPathComponent:@"array-benchmark.csv"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]) {
        NSLog(@"Failed to write benchmark file.");
    }else {
        NSLog(@"Benchmark written.");
    }
}

/*
 NSString *jsonFeed = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.flickr.com/services/feeds/photos_public.gne?tags=soccer&format=json"]];
 jsonFeed = [jsonFeed stringByReplacingOccurrencesOfString:@"jsonFlickrFeed(" withString:@""];
 jsonFeed = [jsonFeed substringToIndex:jsonFeed.length-1];

 id json = [NSJSONSerialization JSONObjectWithData:[jsonFeed dataUsingEncoding:NSASCIIStringEncoding] options:0 error:NULL];

 */

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Helper

static inline id PSPDFEntryForIDX(NSUInteger idx) {
    char buf[100];
    snprintf(buf, 100, "%tu", idx);
    return @(buf);
}

double PSPDFPerformAndTrackTimeMultiple(dispatch_block_t block, NSUInteger runs) {
    // Calculate the median result
    double time = 0;
    for (NSUInteger runIndex = 0; runIndex < runs; runIndex++) {
        time += PSPDFPerformAndTrackTime(block);
    }

    return time/runs;
}

// Benchmark feature. Returns time in nanoseconds. (nsec/1E9 = seconds)
double PSPDFPerformAndTrackTime(dispatch_block_t block) {
    uint64_t startTime = mach_absolute_time();
    block();
    uint64_t endTime = mach_absolute_time();

    // Elapsed time in mach time units
    uint64_t elapsedTime = endTime - startTime;

    // The first time we get here, ask the system
    // how to convert mach time units to nanoseconds
    static double ticksToNanoseconds = 0.0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        ticksToNanoseconds = (double)timebase.numer / timebase.denom;
    });
    
    double elapsedTimeInNanoseconds = elapsedTime * ticksToNanoseconds;
    //NSLog(@"seconds: %f", elapsedTimeInNanoseconds/1E9);
    //printf(".");
    return elapsedTimeInNanoseconds;
}

@end
