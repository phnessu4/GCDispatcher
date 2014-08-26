//
//  Queue.h
//  Queue
//
//  Created by c-mbp13 on 14-8-21.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDispatch.h"

#define GCDSerialQueueName      @"com.stylejar.GCDSerialQueue"      //串行队列名
#define GCDConcurrentQueueName  @"com.stylejar.GCDConcurrentQueue"  //并行队列名

#pragma mark - 异步任务队列, (默认初始化使用global_queue, background级别)

@interface GCDQueue : NSObject

#pragma mark - 初始化单例

/**
 *  @brief 单例对象
 *
 *  @return instance
 */
+ (instancetype)sharedInstance;

/**
 *  @brief 释放单例
 */
+ (void)purgeSharedInstance;

#pragma mark - 属性接口

/**
 *  获取单例中的队列
 *
 *  @return 队列对象
 */
-(dispatch_queue_t)dispatchQueue;

#pragma mark - 任务管理

/**
 *  在队列中创建一个新任务, 首先执行process, process执行完成后回调completion
 *
 *  @param process    任务处理过程调用
 *  @param completion 任务结束回调
 *
 *  @return 任务对象
 */
-(GCDispatch *)dispatch:(dispatch_block_process)process completion:(dispatch_block_completion)completion;

/**
 *  在队列中创建一个新任务, 任务执行完成后无回调
 *
 *  @param process    任务处理过程调用
 *
 *  @return 任务对象
 */
-(GCDispatch *)dispatch:(dispatch_block_process)process;

@end

#pragma mark - 异步串行队列. (创建新队列, 队列名 GCDSerialQueueName)

@interface GCDSerialQueue : GCDQueue

@end

#pragma mark - 异步并行队列. (创建新队列, 队列名 GCDConcurrentQueueName)

@interface GCDConcurrentQueue : GCDQueue

@end
