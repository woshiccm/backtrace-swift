//
//  BackTraceHelper.m
//  backtrace-swift
//
//  Created by roy.cao on 2019/8/15.
//  Copyright © 2019 roy. All rights reserved.
//
// https://stackoverflow.com/questions/4765158/printing-a-stack-trace-from-another-thread
// https://github.com/gnachman/iTerm2/blob/d2cf24a9262432cff459145a73d5e7a5449a65b0/sources/iTermBacktrace.mm
// https://github.com/albertz/openlierox/blob/0.59/src/common/Debug_GetCallstack.cpp


#import <Foundation/Foundation.h>
#include <pthread.h>
#include <execinfo.h>

static pthread_t callingThread = 0;
static pthread_t targetThread = 0;
static void** threadCallstackBuffer = NULL;
static int threadCallstackBufferSize = 0;
static int threadCallstackCount = 0;

#define CALLSTACK_SIG SIGUSR2

// this only can test with Simulator, is x86-64 specific, more in https://github.com/albertz/openlierox/blob/de62596b0b4dc72f8ece135221d7641ca943e592/src/common/Debug_GetPCFromUContext.cpp
//void *GetPCFromUContext(void *secret) {
//    // See this article for further details: (thanks also for some code snippets)
//    // http://www.linuxjournal.com/article/6391
//
//    void *pnt = NULL;
//    // This bit is x86-64 specific. Have fun fixing this when ARM Macs come out next year :)
//    // This might possibly be right: ucp->m_context.ctx.arm_pc
//    ucontext_t* uc = (ucontext_t*) secret;
//    pnt = (void*) uc->uc_mcontext->__ss.__rip ;
//
//    return pnt;
//}

__attribute__((noinline))
static void _callstack_signal_handler(int signr, siginfo_t *info, void *secret) {
    pthread_t myThread = pthread_self();
    //notes << "_callstack_signal_handler, self: " << myThread << ", target: " << targetThread << ", caller: " << callingThread << endl;
    if (myThread != targetThread) {
        return;
    }

    threadCallstackCount = backtrace(threadCallstackBuffer, threadCallstackBufferSize);

    // Search for the frame origin.
    for (int i = 1; i < threadCallstackCount; ++i) {
        if (threadCallstackBuffer[i] != NULL) continue;

        // Found it at stack[i]. Thus remove the first i.
        const int IgnoreTopFrameNum = i;
        threadCallstackCount -= IgnoreTopFrameNum;
        memmove(threadCallstackBuffer, threadCallstackBuffer + IgnoreTopFrameNum, threadCallstackCount * sizeof(void*));

        // this only can test with Simulator, is x86-64 specific
//        threadCallstackBuffer[0] = GetPCFromUContext(secret); // replace by real PC ptr
        break;
    }

    // continue calling thread
    pthread_kill(callingThread, CALLSTACK_SIG);
}

static void _setup_callstack_signal_handler() {
    struct sigaction sa;
    sigfillset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = _callstack_signal_handler;
    sigaction(CALLSTACK_SIG, &sa, NULL);
}

__attribute__((noinline))
int GetCallstack(pthread_t threadId, void **buffer, int size) {
    if (threadId == 0 || threadId == pthread_self()) {
        int count = backtrace(buffer, size);
        static const int IgnoreTopFramesNum = 1; // remove this `GetCallstack` frame
        if (count > IgnoreTopFramesNum) {
            count -= IgnoreTopFramesNum;
            memmove(buffer, buffer + IgnoreTopFramesNum, count * sizeof(void*));
        }
        return count;
    }

    static id callstackMutex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        callstackMutex = [[NSObject alloc] init];
    });

    @synchronized (callstackMutex) {
        callingThread = pthread_self();
        targetThread = threadId;
        threadCallstackBuffer = buffer;
        threadCallstackCount = size;

        _setup_callstack_signal_handler();

        // call _callstack_signal_handler in target thread
        if (pthread_kill(threadId, CALLSTACK_SIG) != 0) {
            return 0;
        }

        {
            sigset_t mask;
            sigfillset(&mask);
            sigdelset(&mask, CALLSTACK_SIG);

            // wait for CALLSTACK_SIG on this thread
//            sigsuspend(&mask);
        }

        threadCallstackBuffer = NULL;
        threadCallstackBufferSize = 0;
        return threadCallstackCount;
    }
}
