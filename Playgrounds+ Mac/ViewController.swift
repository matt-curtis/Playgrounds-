//
//  ViewController.swift
//  macPlaygrounds+
//
//  Created by Matt Curtis on 12/22/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

	//	MARK: - Properties
	
	let mainAppBridge: USBBridge
	
	let uiTestBridge: USBBridge
	
	
	@IBOutlet var selectedPlaygroundLabel: NSTextField!
	
	
	@IBOutlet var codeRunnerStatusLabel: NSTextField!
	
	@IBOutlet var mainAppStatusLabel: NSTextField!
	
	
	@IBOutlet var pushEverythingButton: NSButton!
	
	@IBOutlet var runMyCodeButton: NSButton!
	
	
	var isConnected = false
	
	var watchedFolderURL: URL?
	
	var folderWatcher: FolderWatcher?
	
	
	//	MARK: - Init
	
	required init?(coder: NSCoder) {
		self.mainAppBridge = USBBridge(to: .mainApp)
		self.uiTestBridge = USBBridge(to: .uiTestApp)
		
		super.init(coder: coder)
		
		self.mainAppBridge.onConnectionStateChange = {
			[weak self] connected in
			
			self?.connectionStateDidChange(to: connected)
		}
		
		self.uiTestBridge.onConnectionStateChange = {
			[weak self] connected in
			
			self?.codeRunnerStatusLabel.stringValue = "Code Runner: \(connected ? "Connected" : "Not connected")"
			self?.runMyCodeButton.isEnabled = connected
		}
	}
	
	
	//	MARK: - View Lifecycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
	}
	
	
	//	MARK: - Actions
	
	@IBAction func playgroundSelectButtonClicked(sender: Any) {
		let openPanel = NSOpenPanel()
		
		openPanel.allowsMultipleSelection = false
		openPanel.canChooseDirectories = false
		openPanel.canChooseFiles = true
		openPanel.allowedFileTypes = [ "playground" ]
		
		openPanel.begin {
			[weak self] response in
			
			guard response == .OK, let url = openPanel.urls.first else { return }
			
			self?.watchedFolderURL = url
			self?.folderWatcher = FolderWatcher(url: url) {
				[weak self] changes in
				
				self?.watchedFolderDidChange(changes: changes)
			}
			
			self?.selectedPlaygroundLabel.stringValue = "Pushing \(url.lastPathComponent)"
		}
	}
	
	@IBAction func pushEverythingButtonClicked(sender: Any) {
		guard self.isConnected, let watcher = self.folderWatcher else { return }
		
		self.mainAppBridge.send(data: Data(), ofType: .emptyPlayground)
		
		self.watchedFolderDidChange(changes: (Set(watcher.allSubpaths()), []))
	}
	
	@IBAction func runMyCodeButtonClicked(sender: Any) {
		guard self.isConnected else { return }
		
		self.uiTestBridge.send(data: Data(), ofType: .runMyCode)
	}
	
	
	
	//	MARK: - Helper
	
	func relativePath(from fullPath: String) -> String {
		let folderPathLength = self.watchedFolderURL!.pathComponents.count
		
		var relativePath = (fullPath as NSString).pathComponents.suffix(from: folderPathLength).joined(separator: "/")
		
		var isDirectory: ObjCBool = false
		
		FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)
		
		if isDirectory.boolValue == true {
			relativePath += "/"
		}
		
		return relativePath
	}
	
	
	//	MARK: - Folder Watching
	
	func watchedFolderDidChange(changes: FolderWatcher.SnapshotChanges) {
		//	Run code if an integral file (like a .swift file) changed
		//	We try to do this as early as possible since UI testing is so sloooooooow to dooooo anythiiingggg
		//	Also ignore .xcworkspace files, since those change constanstly, and aren't used by the Playgrounds app (tmk)
		
		do {
			let containsNonWorkspaceChanges = (changes.new.first {
				$0.lowercased().hasSuffix(".xcworkspace") == false
			} != nil)
			
			if containsNonWorkspaceChanges {
				self.uiTestBridge.send(data: Data(), ofType: .runMyCode)
			}
		}
		
		//	Forward changes to app
		
		for path in changes.removed {
			let relativePath = self.relativePath(from: path)
			
			self.mainAppBridge.send(data: relativePath.data(using: .utf8)!, ofType: .fileDelete) {
				switch $0 {
					case .failure(let error):
						print("Failed to send deletion request of \(relativePath) with error: \(error).")
					
					default: break
				}
			}
		}
		
		for path in changes.new {
			let relativePath = self.relativePath(from: path)
			let fileData = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data(bytes: [ 0x1 ])
			let writeRequest = Common.FileWriteRequest(filePath: relativePath, data: fileData)
			
			guard let data = writeRequest.encodeAsData() else {
				print("Failed to encode write request of \(relativePath) as data.")
				
				return
			}
			
			self.mainAppBridge.send(data: data, ofType: .fileWrite) {
				switch $0 {
					case .failure(let error):
						print("Failed to send write request to \(relativePath) with error: \(error).")
					
					default: break
				}
			}
		}
	}
	
	
	//	MARK: - Device Bridge
	
	func connectionStateDidChange(to connected: Bool) {
		self.isConnected = connected
		
		self.pushEverythingButton.stringValue = "Pusher App: \(connected ? "Connected" : "Not connected")"
		self.pushEverythingButton.isEnabled = connected
	}

}

