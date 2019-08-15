//
//  ViewController.swift
//  DemoApp
//
//  Created by roy.cao on 2019/8/15.
//  Copyright © 2019 roy. All rights reserved.
//

import UIKit
import backtrace_swift

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        print(BackTrace.main_thread_t)

        DispatchQueue.global().async {
            let frames = BackTrace.callStack(.main)

            for frame in frames {
                print(frame.demangledSymbol)
            }
        }
    }

    func testA() {
        testB()
    }

    func testB() {

        while true {

        }
    }
}

