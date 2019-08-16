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
            if let pthread = pthread_from_mach_thread_np(self.main_thread_t) {
                if let symbols = getCallStack(pthread) {
                    for symbol in symbols {
                        print(symbol.demangledSymbol)
                    }
                }
            }
        }

        monitoringTimer?.resume()
    }
}
