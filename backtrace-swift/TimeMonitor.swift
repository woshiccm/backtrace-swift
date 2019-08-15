//
//  TimeMonitor.swift
//  backtrace-swift
//
//  Created by roy.cao on 2019/8/15.
//  Copyright © 2019 roy. All rights reserved.
//

import Foundation

public class TimeMonitor: NSObject {

    public static let shared = TimeMonitor()

    let main_thread_t = mach_thread_self()

    var monitoringTimer: DispatchSourceTimer?
    var queue: DispatchQueue?

    public func startMonitor(duration: Double) {
        queue = DispatchQueue(label: "com.backtrace.timeMonitor")
        monitoringTimer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        monitoringTimer?.schedule(deadline: .now() + duration, repeating: 0)
        monitoringTimer?.setEventHandler {
            var symbols = [StackFrame]()
            let stackSize: Int32 = 256
            let addrs = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: Int(stackSize))
            defer { addrs.deallocate() }
            let pthread = pthread_from_mach_thread_np(self.main_thread_t)
            let frameCount = GetCallstack(pthread, addrs, stackSize)
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

            for frame in symbols {
                print(frame.demangledSymbol)
            }
        }

        monitoringTimer?.resume()
    }
}
