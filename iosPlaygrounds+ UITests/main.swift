//
//  iosPlaygrounds__UITests.swift
//  iosPlaygrounds+ UITests
//
//  Created by Matt Curtis on 12/23/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import XCTest

class Main: XCTestCase {
	
	var usbBridge: USBBridge?
	
	
	func testMain() {
		self.continueAfterFailure = true
		
		//	Launch app if not already running
		
		let app = XCUIApplication()
		
		if app.state == .notRunning {
			app.launch()
		}
		
		//	Listen for notifications from bridge...
		
		let playgroundsApp = XCUIApplication(bundleIdentifier: "com.apple.Playgrounds")
		
		self.usbBridge = USBBridge(as: .uiTestApp) {
			_, _ in
			
			print("Run My Code")
			
			self.runMyCode(playgroundsApp)
		}
		
		RunLoop.current.run()
	}
	
	func runMyCode(_ playgroundsApp: XCUIApplication) {
		if playgroundsApp.state != .runningForeground {
			playgroundsApp.activate()
		}
		
		let runCodeButton = playgroundsApp.buttons["Run My Code"]
		let stopButton = playgroundsApp.buttons["Stop"]
		
		if stopButton.exists && stopButton.isHittable {
			stopButton.tap()
			runCodeButton.tap()
		} else if runCodeButton.exists && runCodeButton.isHittable {
			runCodeButton.tap()
		} else {
			//	Either no playground is open, or the playground is in the middle of compiling...?
		}
	}
    
}
