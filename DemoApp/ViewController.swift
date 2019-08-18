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

        TimeMonitor.shared.startMonitor(duration: 0.05)
        testA()
    }

    func testA() {
        testB()
    }

    func testB() {
        testC()
    }

    func testC() {
        while true {

        }
    }
}

