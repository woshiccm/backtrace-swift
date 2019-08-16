//
//  CallStack.swift
//  backtrace-swift
//
//  Created by roy.cao on 2019/8/16.
//  Copyright © 2019 roy. All rights reserved.
//

import Foundation
import Darwin

private var targetThread: pthread_t?
private var callstack: [StackFrame]?

private func signalHandler(code: Int32, info: UnsafeMutablePointer<__siginfo>?, uap: UnsafeMutableRawPointer?) -> Void {
    guard pthread_self() == targetThread else {
        return
    }

    callstack = frame()
}

private func setupCallStackSignalHandler() {
    let action = __sigaction_u(__sa_sigaction: signalHandler)
    var sigActionNew = sigaction(__sigaction_u: action, sa_mask: sigset_t(), sa_flags: SA_SIGINFO)

    if sigaction(SIGUSR2, &sigActionNew, nil) != 0 {
        return
    }
}

public func getCallStack(_ threadId: pthread_t) -> [StackFrame]? {
    if threadId.hashValue == 0 || threadId == pthread_self() {
        return frame()
    }

    targetThread = threadId
    callstack = nil

    setupCallStackSignalHandler()

    if pthread_kill(threadId, SIGUSR2) != 0 {
        return nil
    }

    do {
        var mask = sigset_t()
        sigfillset(&mask)
        sigdelset(&mask, SIGUSR2)
    }

    return callstack
}

private func frame() -> [StackFrame]? {
    var symbols = [StackFrame]()
    let stackSize: UInt32 = 128
    let addrs = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: Int(stackSize))
    defer { addrs.deallocate() }
    let frameCount = backtrace(addrs, Int32(stackSize))
    let buf = UnsafeBufferPointer(start: addrs, count: Int(frameCount))
    for addr in buf {
        guard let addr = addr else { continue }
        var dlInfoPtr = UnsafeMutablePointer<Dl_info>.allocate(capacity: 1)
        defer { dlInfoPtr.deallocate() }
        guard dladdr(addr, dlInfoPtr) != 0 else {
            continue
        }
        let info = dlInfoPtr.pointee
        let symbol = String(cString: info.dli_sname)
        let filename = String(cString: info.dli_fname)
        let symAddrValue = unsafeBitCast(info.dli_saddr, to: UInt64.self)
        let addrValue = UInt64(UInt(bitPattern: addr))
        symbols.append(StackFrame(symbol: symbol, file: filename, address: addrValue, symbolAddress: symAddrValue))
    }
    return symbols
}

extension String {
    fileprivate subscript(range: NSRange) -> String? {
        return Range(range, in: self).flatMap { String(self[$0]) }
    }
}


func dumpStrackTrace() -> String {
    var callstack = [UnsafeMutableRawPointer?](repeating: nil, count: 128)
    var stackTrace = ""

    let frames = backtrace(&callstack, Int32(callstack.count))
    if let symbols = backtrace_symbols(&callstack, frames) {
        let regexp = try! NSRegularExpression(pattern: "^(?:\\S+ +){3}(\\S+) ", options: [])

        for frame in 0 ..< Int(frames) where symbols[frame] != nil {
            let symbol = String(cString: symbols[frame]!)
            if let match = regexp.firstMatch(in: symbol, options: [], range: NSMakeRange(0, symbol.utf16.count)) {
                let symbol = _stdlib_demangleName(symbol[match.range(at: 1)]!)
                stackTrace += symbol + "\n"
                if symbol == "main" {
                    break
                }
            }
        }
        free(symbols)
    }

    return stackTrace
}
