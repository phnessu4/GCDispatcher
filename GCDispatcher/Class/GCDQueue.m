//
//  Queue.m
//  Queue
//
//  Created by c-mbp13 on 14-8-21.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import "GCDQueue.h"
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
-(NSUInteger)asyncSemaphoreMax;

@end


#pragma mark - 默认队列
@interface GCDQueue() <GCDQueueProtocol>
{
    dispatch_queue_t    _asyncQueue;             //队列
    NSUInteger          _asyncSemaphoreMax;      //队列信号最大数(最大线程数)
    
    NSMutableDictionary *_asyncDispatchTimerDic;        //dispatch过程中存储的timer. key为GCDispatch对象
}

@end

@implementation GCDQueue

-(void)setTimer:(dispatch_source_t)timer forDispatchId:(GCDispatchId)Id
{
    [_asyncDispatchTimerDic setObject:timer forKey:@(Id)];
}

-(void)removeTimerByDispatchId:(GCDispatchId)Id
{
    [_asyncDispatchTimerDic removeObjectForKey:@(Id)];
}

-(dispatch_source_t)timerByDispatchId:(GCDispatchId)Id
{
    return [_asyncDispatchTimerDic objectForKey:@(Id)];
}

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
        _asyncQueue          = [self asyncQueue];
        _asyncSemaphoreMax   = [self asyncSemaphoreMax];
        _asyncDispatchTimerDic = [NSMutableDictionary dictionary];
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

-(NSUInteger)asyncSemaphoreMax{
    return [[NSProcessInfo processInfo] processorCount] * 2;
}

#pragma mark - 属性接口
-(dispatch_queue_t)dispatchQueue
{
    return _asyncQueue;
}

#pragma mark - 任务管理 (非timer, 直接添加到队列中执行)
-(GCDispatch *)dispatch:(dispatch_block_process)process
{
    return [self dispatch:process completion:nil];
}

-(GCDispatch *)dispatch:(dispatch_block_process)process completion:(dispatch_block_completion)completion
{
    if (process == nil)
        return nil;
    
    @synchronized(self){
        __block GCDispatch *dispatchObj = [[GCDispatch alloc] initDispatch:[process copy] completion:[completion copy]];

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

-(GCDispatch *)dispatch:(dispatch_block_process)process cancle:(dispatch_block_cancle)cancle interval:(uint64_t)interval delta:(uint64_t)delta
{
    if (process == nil){
        return nil;
    }
    
    //创建任务对象
    __block GCDispatch *dispatchObj = [[GCDispatch alloc] initDispatch:[process copy] cancle:[cancle copy]];
    @synchronized(self){@autoreleasepool{
        
        //开始时间 = 现在时间 + 延迟(纳秒级别)
        dispatch_time_t start = dispatch_walltime(DISPATCH_TIME_NOW, delta * NSEC_PER_SEC);

        //间隔时间
        uint64_t iv           = (interval == 0) ? DISPATCH_TIME_FOREVER : interval * NSEC_PER_SEC;
        
        //允许误差时间 (秒 * 纳秒单位)
        uint64_t leeway       = 0 * NSEC_PER_SEC;
    
        //初始化timer
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _asyncQueue);
        dispatch_source_set_timer(timer, start, iv, leeway);
        
        //设置执行函数
        dispatch_source_set_event_handler(timer, ^{
            [dispatchObj process];
        });

        //设置取消函数
        dispatch_source_set_cancel_handler(timer, ^{
            [dispatchObj cancle];
        });
    
        //开始执行
        dispatch_resume(timer);
        
        //将timer句柄保存到数组
        [self setTimer:timer forDispatchId:dispatchObj.Id];
    }}
    return dispatchObj;
}

-(void)cancle:(GCDispatch *)dispatch
{
    @synchronized(self){@autoreleasepool{
        //获取队列中的timer
        dispatch_source_t timer = [self timerByDispatchId:dispatch.Id];

        //判断timer是否已经cancle
        if (dispatch_source_testcancel(timer) == 0) {
            //触发timer的cancle事件
            dispatch_source_cancel(timer);
            //清理队列中的timer
            [self removeTimerByDispatchId:dispatch.Id];
        }
        dispatch = nil;
    }}
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
        dispatch_semaphore_t asyncSemaphore = dispatch_semaphore_create(_asyncSemaphoreMax);
        
        //执行
        dispatch_async(_asyncQueue, ^{@autoreleasepool{
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
        dispatch_semaphore_t asyncSemaphore = dispatch_semaphore_create(_asyncSemaphoreMax);
        
        //执行
        dispatch_group_async(asyncGroup, _asyncQueue, ^{@autoreleasepool{
            process();
        }});
        
        //执行结束后回调
        dispatch_group_notify(asyncGroup, _asyncQueue, ^{@autoreleasepool{
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

-(NSUInteger)asyncSemaphoreMax
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

-(NSUInteger)asyncSemaphoreMax
{
    //并发线程数 = 处理器核数 * 2倍
    //机器配置不一样, 性能不一样, 没有基准倍数, 理论上是cpu switch时间越小越好, 而且switch时间应小于任务执行时间
    return [[NSProcessInfo processInfo] processorCount] * 2;
}

@end