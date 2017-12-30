//
//  FolderWatcher.swift
//  macPlaygrounds+
//
//  Created by Matt Curtis on 12/24/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Foundation

class FolderWatcher {

	//	MARK: - Typealiases
	
	private typealias Snapshot = [ String : Date ]
	
	typealias SnapshotChanges = (new: Set<String>, removed: Set<String>)
	
	typealias OnContentsChangedHandler = (SnapshotChanges) -> Void
	
	
	//	MARK: - Properties
	
	private var url: URL
	
	private var streamRef: FSEventStreamRef?
	
	private var snapshot = Snapshot()
	
	private var onContentsChanged: OnContentsChangedHandler?

	
	//	MARK: - Init/Deinit
	
	init?(url: URL, onContentsChanged: OnContentsChangedHandler? = nil) {
		self.url = url.absoluteURL
		self.onContentsChanged = onContentsChanged
		
		let callback: FSEventStreamCallback = {
			streamRef, contextInfo, numEvents, eventPaths, eventFlags, eventIds in
			
			let watcher = unsafeBitCast(contextInfo, to: FolderWatcher.self)
			
			watcher.folderDidChange()
		}
		
		let latency: CFTimeInterval = 1
		let pathsToWatch = [ self.url.path ] as CFArray
		
		var context = FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
		
		context.info = Unmanaged.passUnretained(self).toOpaque()
		
		guard
			let streamRef = FSEventStreamCreate(
				nil,
				callback,
				&context,
				pathsToWatch,
				FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
				latency,
				FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
			)
		else {
			return nil
		}
		
		self.streamRef = streamRef
		self.snapshot = self.takeSnapshot()
		
		FSEventStreamScheduleWithRunLoop(streamRef, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
		FSEventStreamStart(streamRef)
	}
	
	deinit {
		guard let streamRef = self.streamRef else {
			return
		}
		
		self.streamRef = nil
		
		FSEventStreamStop(streamRef)
		FSEventStreamInvalidate(streamRef)
		FSEventStreamRelease(streamRef)
	}
	
	
	//	MARK: - Events
	
	private func folderDidChange() {
		let newSnapshot = self.takeSnapshot()
		let comparison = self.compareSnapshots(old: self.snapshot, new: newSnapshot)
		
		if comparison.new.count > 0 || comparison.removed.count > 0 {
			self.onContentsChanged?(comparison)
		}
		
		self.snapshot = newSnapshot
	}
	
	
	//	MARK: - Ease
	
	func allSubpaths() -> [ String ] {
		var subpaths: [ String ] = []
		
		let enumerator = FileManager.default.enumerator(at: self.url, includingPropertiesForKeys: [])
		
		while let fileURL = enumerator?.nextObject() as? URL {
			subpaths.append(fileURL.path)
		}
		
		return subpaths
	}
	
	
	//	MARK: - Snapshots
	
	private func takeSnapshot() -> Snapshot {
		var snapshot = Snapshot()
		
		let enumerator = FileManager.default.enumerator(at: self.url, includingPropertiesForKeys: [ .contentModificationDateKey ])
		
		while let fileURL = enumerator?.nextObject() as? URL {
			guard let date = try? fileURL.resourceValues(forKeys: [ .contentModificationDateKey ]).contentModificationDate else {
				continue
			}
			
			snapshot[fileURL.path] = date
		}
		
		return snapshot
	}
	
	private func compareSnapshots(old: Snapshot, new: Snapshot) -> SnapshotChanges {
		var newPaths: Set<String> = []
		var removedPaths = Set(old.keys)
		
		for (path, timestamp) in new {
			if let previousTimestamp = old[path] {
				//	This path exists in both new and old, so not moved/deleted
				
				removedPaths.remove(path)
				
				//	Compare timestamps to see if it's changed/new
				
				if previousTimestamp != timestamp {
					//	Timestamps differ, so - new
					
					newPaths.insert(path)
				}
			} else {
				//	This path didn't even exist in the old, so definitely new...
				
				newPaths.insert(path)
			}
		}
		
		return (newPaths, removedPaths)
	}

}
