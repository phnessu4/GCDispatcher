//
//  GCDispatch.h
//  Queue
//
//  Created by c-mbp13 on 14-8-25.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GCDispatch;

typedef int32_t GCDispatchId;       //任务id  32位 int
typedef int64_t GCDispatchId_64;    //任务id  64位 long long

typedef enum
{
    GCD_Dispatch_Result_Null      = 0,    //空
    GCD_Dispatch_Result_Success   = 1,    //成功
    GCD_Dispatch_Result_Failure   = 2,    //失败
}
GCDDispatchResult;  //任务结果

typedef enum
{
    GCD_Dispatch_Execute_Once   = 0,    //执行一次(默认)
    GCD_Dispatch_Execute_Repeat = 1,    //重复执行
}
GCDDispatchExecute; //任务执行方式

typedef void (^dispatch_block_process)(void);                       //任务处理过程
typedef void (^dispatch_block_completion)(GCDispatch *dispatch);    //任务结束回调

@interface GCDispatch : NSObject

@property (atomic, assign) GCDispatchId       Id;           //任务id 32位
@property (atomic, assign) GCDispatchId_64    Id_64;        //任务id 64位
@property (atomic, assign) GCDDispatchResult  result;       //任务处理结果
@property (atomic, assign) GCDDispatchExecute execute;      //任务执行方式
@property (atomic, strong) NSException        *exception;   //任务异常结果(非异常为空)
@property (atomic, assign) dispatch_source_t  timer;

/**
 *  初始化任务
 *
 *  @param process    任务处理过程
 *  @param completion 任务结束回调
 *
 *  @return 任务对象
 */
-(instancetype)initDispatch:(dispatch_block_process)process completion:(dispatch_block_completion)completion;

-(instancetype)initDispatch:(dispatch_block_process)process;

/**
 *  开始处理任务
 */
-(void)process;

/**
 *  任务结束回调
 */
-(void)completion;

@end
