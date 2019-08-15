//
//  BackTrace.swift
//  backtrace-swift
//
//  Created by roy.cao on 2019/8/15.
//  Copyright © 2019 roy. All rights reserved.
//

import Foundation

extension Character {
    var isAscii: Bool {
        return unicodeScalars.allSatisfy { $0.isASCII }
    }
    var ascii: UInt32? {
        return isAscii ? unicodeScalars.first?.value : nil
    }
}

extension String {
    var ascii : [Int8] {
        var unicodeValues = [Int8]()
        for code in unicodeScalars {
            unicodeValues.append(Int8(code.value))
        }
        return unicodeValues
    }
}

public struct StackFrame {
    public let symbol: String
    public let file: String
    public let address: UInt64
    public let symbolAddress: UInt64

    public var demangledSymbol: String {
        return _stdlib_demangleName(symbol)
    }
}

public class BackTrace: NSObject {

    public static let main_thread_t = mach_thread_self()

    public enum CallStackType {
        case all
        case main
        case current
    }

//    public static func callStack(with type: CallStackType) -> [StackFrame] {
//        return []
//    }

    public static func callStack(_ thread: Thread) -> [StackFrame] {
        var symbols = [StackFrame]()
        let stackSize: Int32 = 256
        let addrs = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: Int(stackSize))
        defer { addrs.deallocate() }
        guard let pthread = pthread_from_mach_thread_np(transformToMachThread(thread)) else {
            return []
        }

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
        return symbols
    }

    static func transformToMachThread(_ thread: Thread) -> thread_t {
        var name: [Int8] = [Int8]()
        var count: mach_msg_type_number_t = 0
        var threads: thread_act_array_t?

        if task_threads(mach_task_self_, &(threads), &count) != KERN_SUCCESS {
            return mach_thread_self()
        }

        let tread_name = thread.name
        if thread.isMainThread {
            return self.main_thread_t
        }

        for i in 0..<count {
            if let p_thread = pthread_from_mach_thread_np((threads![Int(i)])) {
                name.append(Int8(Character.init("\0").ascii!))
                pthread_getname_np(p_thread, &name, MemoryLayout<Int8>.size * 256)
                if (strcmp(&name, (thread.name!.ascii)) == 0) {
                    thread.name = tread_name
                    return threads![Int(i)]
                }
            }
        }

        thread.name = tread_name
        return mach_thread_self()
    }
}

@_silgen_name("backtrace")
public func backtrace(_ stack: UnsafeMutablePointer<UnsafeMutableRawPointer?>!, _ maxSymbols: Int32) -> Int32
@_silgen_name("backtrace_symbols")
public func backtrace_symbols(_ stack: UnsafePointer<UnsafeMutableRawPointer?>!, _ frame: Int32) -> UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>!

@_silgen_name("swift_demangle")
public
func _stdlib_demangleImpl(
    mangledName: UnsafePointer<CChar>?,
    mangledNameLength: UInt,
    outputBuffer: UnsafeMutablePointer<CChar>?,
    outputBufferSize: UnsafeMutablePointer<UInt>?,
    flags: UInt32
    ) -> UnsafeMutablePointer<CChar>?

public func _stdlib_demangleName(_ mangledName: String) -> String {
    return mangledName.utf8CString.withUnsafeBufferPointer {
        (mangledNameUTF8CStr) in

        let demangledNamePtr = _stdlib_demangleImpl(
            mangledName: mangledNameUTF8CStr.baseAddress,
            mangledNameLength: UInt(mangledNameUTF8CStr.count - 1),
            outputBuffer: nil,
            outputBufferSize: nil,
            flags: 0)

        if let demangledNamePtr = demangledNamePtr {
            let demangledName = String(cString: demangledNamePtr)
            free(demangledNamePtr)
            return demangledName
        }
        return mangledName
    }
}
