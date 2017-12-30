//
//  AppDelegate.swift
//  macPlaygrounds+
//
//  Created by Matt Curtis on 12/22/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	var statusItem: NSStatusItem!
	
	var mainWindowController: NSWindowController!


	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
		
		self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		
		self.statusItem.image = NSImage(named: .init(rawValue: "MenubarIcon"))
		self.statusItem.image?.isTemplate = true
		
		self.statusItem.target = self
		self.statusItem.action = #selector(menubarItemClicked)
		
		
		let storyboard = NSStoryboard(name: .init(rawValue: "Main"), bundle: nil)
		
		guard
			let mainWC = storyboard.instantiateController(withIdentifier: .init(rawValue: "MainWindowController")) as? NSWindowController
		else {
		   fatalError("Error getting main window controller")
		}
		
		self.mainWindowController = mainWC
	}
	
	
	@objc func menubarItemClicked() {
		guard
			let statusItemWindow = NSApp.currentEvent?.window,
			let mainWindow = self.mainWindowController.window
		else {
			return
		}
		
		let size = mainWindow.frame.size
		let frame = NSRect(
			x: (statusItemWindow.frame.midX - (size.width / 2)) + 10,
			y: statusItemWindow.frame.minY - size.height,
			width: size.width,
			height: size.height
		)
		
		mainWindow.setFrame(frame, display: true)
		mainWindow.makeKeyAndOrderFront(nil)
	}

}

