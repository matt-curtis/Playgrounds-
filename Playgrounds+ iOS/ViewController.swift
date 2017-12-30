//
//  ViewController.swift
//  Playgrounds+
//
//  Created by Matt Curtis on 12/22/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIDocumentPickerDelegate {

	//	MARK: - Properties

	var playground: PlaygroundBundle?
	
	let usbBridge: USBBridge
	
	
	//	MARK: - Init
	
	required init?(coder aDecoder: NSCoder) {
		self.usbBridge = USBBridge(as: .mainApp)
		
		super.init(coder: aDecoder)
		
		self.usbBridge.onIncomingData = {
			[weak self] data, type in
			
			self?.handleIncomingData(data: data, type: type)
		}
	}
	
	
	//	MARK: - UI Actions
	
	@IBAction func selectPlayground(_ sender: Any) {
		let picker = UIDocumentPickerViewController(documentTypes: [ "com.apple.dt.playground" ], in: .open)
		
		picker.modalPresentationStyle = .popover
		picker.preferredContentSize = CGSize(width: 600, height: 600)
		
		if let view = self.view, let popoverPresentationController = picker.popoverPresentationController {
			popoverPresentationController.sourceView = view
			popoverPresentationController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
			popoverPresentationController.permittedArrowDirections = []
		}
		
		picker.delegate = self
		
		self.present(picker, animated: true, completion: nil)
	}
	
	@IBAction func openPlaygroundsApp(_ sender: Any) {
		//	Gotta love private APIs! :)
		
		let workspace = (NSClassFromString("LSApplicationWorkspace") as? NSObject.Type)?.init()
		let selector = Selector(("openApplicationWithBundleID:"))
		
		if workspace?.responds(to: selector) == true {
			_ = workspace?.perform(selector, with: "com.apple.Playgrounds")
		}
	}
	
	
	//	MARK: - Document Picker
	
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		guard let playgroundURL = urls.first else {
			print("No playground selected?")
			
			return
		}
		
		self.playground = PlaygroundBundle(securityScopedURL: playgroundURL)
	}
	
	
	//	MARK: - Incoming File
	
	func handleIncomingData(data: Data, type: Common.DataType) {
		switch type {
			case .emptyPlayground:
				print("Emptying playground...")
				
				self.playground?.empty()
			
			case .fileDelete:
				if let playground = self.playground, let path = String(bytes: data, encoding: .utf8) {
					print("Deleting \(path)")
					
					playground.delete(path: path)
				} else {
					print("Received playground delete request while not having any playground open - ignoring...")
				}
		
			case .fileWrite:
				guard let fileWriteRequest = Common.FileWriteRequest(decodedFrom: data) else {
					print("Failed to decode write request.")
					
					return
				}
				
				if let playground = self.playground {
					print("Writing to \(fileWriteRequest.filePath)")
					
					playground.write(data: fileWriteRequest.data, to: fileWriteRequest.filePath)
				} else {
					print("Received playground write request while not having any playground open - ignoring...")
				}
			
			default: break
		}
	}
	
}

