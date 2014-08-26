//
//  Queue.m
//  Queue
//
//  Created by c-mbp13 on 14-8-21.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import "GCDQueue.h"
#import <libkern/OSAtomic.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>

#define ENABLE_ASSERT   0
#if ENABLE_ASSERT
#define STAssert(condition, desc, ...) NSAssert(condition, desc, ##__VA_ARGS__)
#else
#define STAssert(condition, desc, ...) {NSLog(@"\n--------------\nNSAssert %@\n--------------",desc);}
#endif

#pragma mark - Queue内部协议

@protocol GCDQueueProtocol <NSObject>

/**
 *  获取队列对象
 *
 *  @return 队列对象
 */
-(dispatch_queue_t)asyncQueue;

/**
 *  获取队列信号最大数(最大线程数, 最大不应该超过cpu核数*2, 线程倍数根据机型性能而定)
 *
 *  @return 信号数量
 */
-(int)asyncSemaphoreMax;

@end


#pragma mark - 默认队列

@interface GCDQueue() <GCDQueueProtocol>
{
    dispatch_queue_t    asyncQueue;             //队列
    int64_t             asyncQueueIndex;        //队列索引
    int                 asyncSemaphoreMax;      //队列信号最大数(最大线程数)
}

@end

@implementation GCDQueue

#pragma mark - 初始化单例

+ (instancetype)sharedInstance
{
    Class selfClass = [self class];
    id sharedInstance = objc_getAssociatedObject(self, @"kDPSingleton");
    @synchronized(self) {
        if (!sharedInstance) {
            sharedInstance = [[selfClass alloc] initInstance];
            objc_setAssociatedObject(selfClass, @"kDPSingleton", sharedInstance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return sharedInstance;
}

+(void)purgeSharedInstance
{
    Class selfClass = [self class];
    objc_setAssociatedObject(selfClass, @"kDPSingleton", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

-(instancetype)init{
    STAssert(false, @"init not available");
    return nil;
}

-(instancetype)copy{
    STAssert(false, @"copy not available");
    return nil;
}

-(instancetype)mutableCopy{
    STAssert(false, @"mutableCopy not available");
    return nil;
}

-(instancetype)initInstance
{
    if ((self = [super init]))
    {
        asyncQueueIndex   = 0;
        asyncQueue        = [self asyncQueue];
        asyncSemaphoreMax = [self asyncSemaphoreMax];
    }
    return self;
}

#if NEEDS_DISPATCH_RETAIN_RELEASE
-(void)dealloc
{
    NSLog(@"release asyncQueue");
	dispatch_release(asyncQueue);
}
#endif

#pragma mark - 内部协议接口

-(dispatch_queue_t)asyncQueue
{
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
}

-(int)asyncSemaphoreMax{
    return [[NSProcessInfo processInfo] processorCount] * 2;
}

#pragma mark - 属性接口
-(dispatch_queue_t)dispatchQueue
{
    return asyncQueue;
}

#pragma mark - 任务管理
-(GCDispatch *)dispatch:(dispatch_block_process)process
{
    return [self dispatch:process completion:nil];
}

-(GCDispatch *)dispatch:(dispatch_block_process)process completion:(dispatch_block_completion)completion
{
    if (process == nil)
        return nil;
    
    @synchronized(self){
        GCDispatch *dispatchObj = [[GCDispatch alloc] initWithDispatchId:OSAtomicIncrement64(&(asyncQueueIndex))
                                            process:[process copy]
                                         completion:[completion copy]];

        //处理任务, 如果没有完成后回调, 直接返回
        if (!completion) {
            [self dispatchAsync:^{
                [dispatchObj process];
            }];
            return dispatchObj;
        }
        
        //处理任务, 完成后回调
        [self dispatchAsyncGroup:^{
            [dispatchObj process];
        } completion:^{
            [dispatchObj completion];
        }];
        return dispatchObj;
    }
}

#pragma mark - 私有函数, 线程任务实现

/**
 *  添加任务到队列 (直接异步调用)
 *
 *  @param process 任务函数
 */
-(void)dispatchAsync:(dispatch_block_t)process
{
    @synchronized(self){@autoreleasepool{
        
        //设定线程信号数
        dispatch_semaphore_t asyncSemaphore = dispatch_semaphore_create(asyncSemaphoreMax);
        
        //执行
        dispatch_async(asyncQueue, ^{@autoreleasepool{
            process();
            //任务处理完毕, 线程信号-1
            dispatch_semaphore_signal(asyncSemaphore);
        }});
        
        //释放资源
        #if NEEDS_DISPATCH_RETAIN_RELEASE
        dispatch_release(jobSemaphore);
        #endif
        asyncSemaphore = nil;
    }}
}

/**
 *  添加任务到队列 (添加到dispatch group, process结束后执行completion)
 *
 *  @param process      任务处理函数
 *  @param completion   任务完成回调
 */
-(void)dispatchAsyncGroup:(dispatch_block_t)process completion:(dispatch_block_t)completion
{
    @synchronized(self){@autoreleasepool{
        
        //创建任务group
        dispatch_group_t asyncGroup = dispatch_group_create();
        //设定线程信号数
        dispatch_semaphore_t asyncSemaphore = dispatch_semaphore_create(asyncSemaphoreMax);
        
        //执行
        dispatch_group_async(asyncGroup, asyncQueue, ^{@autoreleasepool{
            process();
        }});
        
        //执行结束后回调
        dispatch_group_notify(asyncGroup, asyncQueue, ^{@autoreleasepool{
            completion();
            
            //任务处理完毕, 线程信号-1
            dispatch_semaphore_signal(asyncSemaphore);
        }});
        
        //等待当前组任务全部完成
        dispatch_group_wait(asyncGroup, DISPATCH_TIME_FOREVER);
        
        //释放资源
        #if NEEDS_DISPATCH_RETAIN_RELEASE
        dispatch_release(jobSemaphore);
        dispatch_release(group);
        #endif
        asyncSemaphore = nil;
        asyncGroup = nil;
    }}
}

@end

#pragma mark - 异步串行队列

@interface GCDSerialQueue ()<GCDQueueProtocol>@end
@implementation GCDSerialQueue

-(dispatch_queue_t)asyncQueue
{
    return dispatch_queue_create([GCDSerialQueueName cStringUsingEncoding:NSUTF8StringEncoding], NULL);
}

-(int)asyncSemaphoreMax
{
    return [[NSProcessInfo processInfo] processorCount];
}

@end

#pragma mark - 异步并行队列

@interface GCDConcurrentQueue ()<GCDQueueProtocol>@end
@implementation GCDConcurrentQueue

-(dispatch_queue_t)asyncQueue
{
    return dispatch_queue_create([GCDConcurrentQueueName cStringUsingEncoding:NSUTF8StringEncoding], DISPATCH_QUEUE_CONCURRENT);
}

-(int)asyncSemaphoreMax
{
    //并发线程数 = 处理器核数 * 2倍
    //机器配置不一样, 性能不一样, 没有基准倍数, 理论上是cpu switch时间越小越好, 而且switch时间应小于任务执行时间
    return [[NSProcessInfo processInfo] processorCount] * 2;
}

@end