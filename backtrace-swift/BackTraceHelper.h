//
//  BackTraceHelper.h
//  backtrace-swift
//
//  Created by roy.cao on 2019/8/15.
//  Copyright © 2019 roy. All rights reserved.
//

#import <Foundation/Foundation.h>

int GetCallstack(pthread_t threadId, void **buffer, int size);
