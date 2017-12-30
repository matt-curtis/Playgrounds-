//
//  MainWindow.swift
//  macPlaygrounds+
//
//  Created by Matt Curtis on 12/27/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import AppKit

class MainWindow: NSWindow {

	override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
		super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
		
		self.level = .statusBar
		self.collectionBehavior = [ .moveToActiveSpace, .fullScreenAuxiliary ]
		
		self.isOpaque = false
		self.backgroundColor = .clear
	}
	
	
	override var canBecomeKey: Bool {
		return true
	}
	
	override func resignKey() {
		super.resignKey()
		
		self.close()
	}
	
}
