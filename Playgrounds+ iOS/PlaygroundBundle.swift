//
//  PlaygroundBundle.swift
//  BTPlayground
//
//  Created by Matt Curtis on 12/22/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Foundation

class PlaygroundBundle {
	
	//	MARK: - Properties
	
	let url: URL
	
	
	//	MARK: - Init
	
	init(securityScopedURL url: URL) {
		self.url = url
		
		_ = self.url.startAccessingSecurityScopedResource()
	}
	
	deinit {
		self.url.stopAccessingSecurityScopedResource()
	}
	
	
	//	MARK: - File System
	
	private func coordinateWrite(at path: String, options: NSFileCoordinator.WritingOptions, write: @escaping (URL) -> Void) {
		guard
			let percentEncodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
			let url = URL(string: percentEncodedPath, relativeTo: self.url)?.absoluteURL
		else {
			print("Failed to form valid URL with \(path).")
			
			return
		}
		
		DispatchQueue.global(qos: .userInteractive).async {
			let fileCoordinator = NSFileCoordinator()
			var coordinationError: NSError?
			
			fileCoordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) {
				newURL in
				
				write(newURL)
			}
			
			if let error = coordinationError {
				print("Coordination error: \(error)")
			}
		}
	}
	
	func empty() {
		self.coordinateWrite(at: self.url.path, options: .forReplacing) {
			newURL in
			
			let enumerator = FileManager.default.enumerator(at: newURL, includingPropertiesForKeys: nil)
		
			while let fileURL = enumerator?.nextObject() as? URL {
				try? FileManager.default.removeItem(at: fileURL)
			}
		}
	}
	
	func delete(path: String) {
		self.coordinateWrite(at: path, options: .forReplacing) {
			newURL in
			
			try? FileManager.default.removeItem(at: newURL)
		}
	}
	
	func write(data: Data, to path: String) {
		let isDirectory = path.last == "/"
		let fm = FileManager.default
		
		self.coordinateWrite(at: path, options: .forReplacing) {
			newURL in
			
			if isDirectory {
				try? fm.createDirectory(at: newURL, withIntermediateDirectories: true, attributes: nil)
			} else {
				try? fm.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
				
				try? fm.removeItem(at: newURL)
				
				if fm.createFile(atPath: newURL.path, contents: data, attributes: nil) == false {
					print("Failed to write to \(path).")
				}
			}
		}
	}

}
