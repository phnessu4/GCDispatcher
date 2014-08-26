//
//  GCDDispatch.h
//  Queue
//
//  Created by c-mbp13 on 14-8-25.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GCDispatch;

typedef int64_t GCDDispatchId;    //任务id

typedef enum
{
    GCD_Dispatch_Result_Null      = 0,    //空
    GCD_Dispatch_Result_Success   = 1,    //成功
    GCD_Dispatch_Result_Failure   = 2,    //失败
}
GCDDispatchResult;  //任务结果

typedef void (^dispatch_block_process)(void);                       //任务处理过程
typedef void (^dispatch_block_completion)(GCDispatch *dispatch);   //任务结束回调


@interface GCDispatch : NSObject

@property (atomic, assign) GCDDispatchId     Id;                //任务id
@property (atomic, assign) GCDDispatchResult result;            //任务处理结果
@property (atomic, strong) NSException       *exception;        //任务异常结果(非异常为空)

/**
 *  初始化任务
 *
 *  @param dispatchId 任务id
 *  @param process    任务处理过程
 *  @param completion 任务结束回调
 *
 *  @return 任务对象
 */
-(instancetype)initWithDispatchId:(GCDDispatchId)dispatchId process:(dispatch_block_process)process completion:(dispatch_block_completion)completion;

/**
 *  开始处理任务
 */
-(void)process;

/**
 *  任务结束回调
 */
-(void)completion;

@end
