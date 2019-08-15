//
//  ViewController.swift
//  BackTrace
//
//  Created by roy.cao on 2019/8/15.
//  Copyright © 2019 roy. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let main_thread_t = mach_thread_self()

    override func viewDidLoad() {
        super.viewDidLoad()
        testA()
    }

    func testA() {
        testB()
    }

    func testB() {
        DispatchQueue.global().async {
            let thread = self.transformToMachThread(Thread.main)
            GetBacktraceFrames(pthread_from_mach_thread_np(thread))
        }
    }

    func transformToMachThread(_ thread: Thread) -> thread_t {
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

