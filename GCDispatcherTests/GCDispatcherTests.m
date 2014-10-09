//
//  GCDispatcherTests.m
//  GCDispatcherTests
//
//  Created by c-mbp13 on 14-8-26.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <sys/time.h>
#import "GCDispatcher.h"

@interface GCDispatcherTests : XCTestCase

@end

@implementation GCDispatcherTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

struct timeval gStartTime;

void Start(void)
{
    gettimeofday(&gStartTime, NULL);
}

void End(void)
{
    struct timeval endtv;
    gettimeofday(&endtv, NULL);
    
    double start = gStartTime.tv_sec * 1000000 + gStartTime.tv_usec;
    double end = endtv.tv_sec * 1000000 + endtv.tv_usec;
    
    NSLog(@"---------------Operation took %f seconds to complete", (end - start) / 1000000.0);
}

-(void)testQueueFunction
{
    NSArray *queue = @[[GCDQueue class],
                       [GCDSerialQueue class],
                       [GCDConcurrentQueue class],];
    for (Class queueClass in queue) {
        NSLog(@"------------ class %@ start test ", queueClass);
        
        [self dynamicQueueFunction:queueClass];
        [self dynamicQueue:queueClass];
        
        NSLog(@"------------ class %@ ending test ", queueClass);
    }
}

-(void)dynamicQueueFunction:(Class)queueClass
{
    {
        XCTAssertFalse([[queueClass alloc] init], @"init should not work");
        XCTAssertFalse([[queueClass alloc] copy], @"copy should not work");
        XCTAssertFalse([[queueClass alloc] mutableCopy], @"mutableCopy should not work");
    }
    {
        GCDispatch *dispatchFail1 = [[queueClass sharedInstance] dispatch:nil completion:nil];
        XCTAssertNil(dispatchFail1, @"dispatch should be nil %@",dispatchFail1);
        
        GCDispatch *dispatchFail2 = [[queueClass sharedInstance] dispatch:nil completion:^(GCDispatch *dispatch) {}];
        XCTAssertNil(dispatchFail2, @"dispatch should be nil %@",dispatchFail2);
        [queueClass purgeSharedInstance];
    }
    {
        GCDispatch *dispatchFail3 = [[queueClass sharedInstance] dispatch:^{
            @throw [NSException exceptionWithName:@"com.unit.test" reason:@"throw" userInfo:nil];
        } completion:nil];
        sleep(2);
        XCTAssert(dispatchFail3.result == GCD_Dispatch_Result_Failure, @"dispatch should be fail %@", dispatchFail3.exception);
        NSLog(@"------------ dispatchFail3 exception %@", dispatchFail3.exception);
        
        GCDispatch *dispatchFail4 = [[queueClass sharedInstance] dispatch:^{
            @throw [NSException exceptionWithName:@"com.unit.test" reason:@"throw" userInfo:nil];
        } completion:^(GCDispatch *dispatch) {}];
        sleep(2);
        XCTAssert(dispatchFail4.result == GCD_Dispatch_Result_Failure, @"dispatch should be fail %@", dispatchFail4.exception);
        NSLog(@"------------ dispatchFail4 exception %@", dispatchFail3.exception);
        
        GCDispatch *dispatchFail5 = [[queueClass sharedInstance] dispatch:^{} completion:^(GCDispatch *dispatch) {
            @throw [NSException exceptionWithName:@"com.unit.test" reason:@"throw" userInfo:nil];
        }];
        sleep(2);
        XCTAssert(dispatchFail5.result == GCD_Dispatch_Result_Failure, @"dispatch should be fail %@", dispatchFail5.exception);
        NSLog(@"------------ dispatchFail5 exception %@", dispatchFail5.exception);
        
        GCDispatch *dispatchFail6 = [[queueClass sharedInstance] dispatch:^{
            @throw [NSException exceptionWithName:@"com.unit.process.test" reason:@"throw" userInfo:nil];
        } completion:^(GCDispatch *dispatch) {
            @throw [NSException exceptionWithName:@"com.unit.completion.test" reason:@"throw" userInfo:nil];
        }];
        sleep(2);
        XCTAssert(dispatchFail6.result == GCD_Dispatch_Result_Failure, @"dispatch should be fail %@", dispatchFail6.exception);
        XCTAssert([dispatchFail6.exception.name isEqualToString:@"com.unit.process.test"], @"dispatch exception should be com.unit.process.test != %@", dispatchFail6.exception);
        NSLog(@"------------ dispatchFail6 exception %@", dispatchFail6.exception);
        [queueClass purgeSharedInstance];
    }
    {
        GCDispatch *dispatchFail7 = [[queueClass sharedInstance] dispatch:nil];
        XCTAssertNil(dispatchFail7, @"dispatchFail7 should be nil %@",dispatchFail7);
        
        GCDispatch *dispatchFail8 = [[queueClass sharedInstance] dispatch:^{
            @throw [NSException exceptionWithName:@"com.unit.test" reason:@"throw" userInfo:nil];
        }];
        sleep(2);
        XCTAssert(dispatchFail8.result == GCD_Dispatch_Result_Failure, @"dispatch should be fail %@", dispatchFail8.exception);
        NSLog(@"------------ dispatchFail8 exception %@", dispatchFail8.exception);
        [queueClass purgeSharedInstance];
    }
    {
        GCDispatch *dispatchSuccess1 = [[queueClass sharedInstance] dispatch:^{}];
        sleep(2);
        XCTAssert(dispatchSuccess1.result == GCD_Dispatch_Result_Success, @"dispatch should success %@",dispatchSuccess1.exception);
        
        GCDispatch *dispatchSuccess2 = [[queueClass sharedInstance] dispatch:^{} completion:nil];
        sleep(2);
        XCTAssert(dispatchSuccess2.result == GCD_Dispatch_Result_Success, @"dispatch should success %@",dispatchSuccess2.exception);
        
        GCDispatch *dispatchSuccess3 = [[queueClass sharedInstance] dispatch:^{} completion:^(GCDispatch *dispatch) {}];
        sleep(2);
        XCTAssert(dispatchSuccess3.result == GCD_Dispatch_Result_Success, @"dispatch should success %@",dispatchSuccess3.exception);
        [queueClass purgeSharedInstance];
    }
}

-(void)dynamicQueue:(Class)queueClass
{
    Start();
    @autoreleasepool {
        int dispatch_count = 10000;
        for (int i = 1; i <= dispatch_count; i++) {
            @autoreleasepool {
                if (i % 2 ==0) {
                    [[queueClass sharedInstance] dispatch:^{
                        NSLog(@"------------ process doing something %d without completion",i);
                    }];
                }else{
                    [[queueClass sharedInstance] dispatch:^{
                        NSLog(@"------------ process doing something %d with completion",i);
                    } completion:^(GCDispatch *dispatch) {
                        NSLog(@"------------ completion id: %d id64: %lld", dispatch.Id, dispatch.Id_64);
                    }];
                }
            }
        }
        [queueClass purgeSharedInstance];
    }
    End();
}

-(void)testSourceTimer
{
    GCDispatch *obj = [[GCDSerialQueue sharedInstance] dispatch:^{
        NSLog(@"hello world");
        
    } cancle:^(GCDispatch *dispatch) {
        NSLog(@"------------ cancle");
    } interval:1 delta:0];
    NSLog(@"obj id %d", obj.Id);
    
    GCDispatch *obj2 = [[GCDSerialQueue sharedInstance] dispatch:^{
        NSLog(@"hello world2");
        
    } cancle:^(GCDispatch *dispatch) {
        NSLog(@"------------ cancle2");
    } interval:1 delta:0];
    NSLog(@"obj2 id %d", obj2.Id);

    sleep(5);
    [[GCDSerialQueue sharedInstance] cancle:obj];
    sleep(5);
    [[GCDSerialQueue sharedInstance] cancle:obj2];
    NSLog(@"------------ cancle obj %d", obj.Id);
    sleep(10);
    NSLog(@"------------ test over");
}

@end
