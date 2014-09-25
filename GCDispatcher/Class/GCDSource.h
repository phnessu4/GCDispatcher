//
//  GCDSource.h
//  GCDispatcher
//
//  Created by c-mbp13 on 14-9-25.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import "GCDQueue.h"

@interface GCDSource : GCDQueue

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

-(GCDispatch *)dispatch:(dispatch_block_process)process completion:(dispatch_block_completion)completion interval:(uint64_t)interval repeats:(BOOL)yesOrNo;

-(GCDispatch *)dispatch:(dispatch_block_process)process interval:(uint64_t)interval repeats:(BOOL)yesOrNo;

@end
