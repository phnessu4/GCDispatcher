//
//  GCDDispatch.m
//  Queue
//
//  Created by c-mbp13 on 14-8-25.
//  Copyright (c) 2014年 stylejar. All rights reserved.
//

#import "GCDispatch.h"

#define GCDDispatchExceptionName  @"GCDDispatchException"

@interface GCDispatch()
{
    dispatch_block_process    _process;      //需要异步执行的block
    dispatch_block_completion _completion;   //结束后调用
}

@end

@implementation GCDispatch

- (instancetype)initWithDispatchId:(GCDDispatchId)dispatchId process:(dispatch_block_process)process completion:(dispatch_block_completion)completion;
{
    self = [super init];
    if (self) {
        _Id     = dispatchId;
        _result = GCD_Dispatch_Result_Null;
        
        _process    = process;
        _completion = completion;
        _exception  = nil;
    }
    return self;
}

-(void)process
{
    @synchronized(self){
        
        //如果任务执行函数为空, 直接报错返回
        if (!_process) {
            _result    = GCD_Dispatch_Result_Failure;
            _exception = [NSException exceptionWithName:GCDDispatchExceptionName reason:@"process handler is nil" userInfo:nil];
            return;
        }
        
        //处理任务, 捕捉异常并返回, 主要是防止线程crash导致整个程序挂了
        @try {
            _result = GCD_Dispatch_Result_Success;
            _process();
        }
        @catch (NSException *exception) {
            _result    = GCD_Dispatch_Result_Failure;
            _exception = exception;
        }
    }
}

-(void)completion
{
    @synchronized(self){
        //如果process有异常, 直接返回process异常, completion不在执行
        if (_exception) {
            _result = GCD_Dispatch_Result_Failure;
            return;
        }
        
        //如果任务结束无需处理, 则直接返回
        if (!_completion){
            _result = GCD_Dispatch_Result_Success;
            return;
        }
        
        //任务结束后的处理调用
        @try {
            _result = GCD_Dispatch_Result_Success;
            _completion(self);
        }
        @catch (NSException *exception) {
            _result    = GCD_Dispatch_Result_Failure;
            _exception = exception;
        }
    }
}

@end