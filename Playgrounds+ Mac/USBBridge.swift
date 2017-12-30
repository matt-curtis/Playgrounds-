//
//  USBBridge.swift
//  macPlaygrounds+
//
//  Created by Matt Curtis on 12/22/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Foundation

class USBBridge: NSObject, PTChannelDelegate {

	//	MARK: - Properties
	
	let port: Common.Port
	
	private var connectionState: ConnectionState = .waitingForDevice {
		didSet {
			var wasConnected = false
			var nowConnected = false
			
			if case .connected = oldValue { wasConnected = true }
			if case .connected =  self.connectionState { nowConnected = true }
			
			if wasConnected != nowConnected {
				self.onConnectionStateChange?(nowConnected)
			}
		}
	}
	
	var onConnectionStateChange: ((Bool) -> Void)?
	

	//	MARK: - Init
	
	init(to port: Common.Port, onConnectionStateChange: ((Bool) -> Void)? = nil) {
		self.port = port
		self.onConnectionStateChange = onConnectionStateChange
		
		super.init()
		
		//	Listen for USB device attach/detach
		
		let usbHub = PTUSBHub.shared()
		let nc = NotificationCenter.default
		
		nc.addObserver(self, selector: #selector(deviceDidAttach(_:)), name: .PTUSBDeviceDidAttach, object: usbHub)
		nc.addObserver(self, selector: #selector(deviceDidDetach(_:)), name: .PTUSBDeviceDidDetach, object: usbHub)
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	
	//	MARK: - Debug
	
	func debugPrint(message: String) {
		#if DEBUG
			print("\(type(of: self)) [On port \(self.port)]: \(message)")
		#endif
	}
	
	
	//	MARK: - Device Attach/Detach
	
	@objc private func deviceDidAttach(_ notification: NSNotification) {
		guard case .waitingForDevice = self.connectionState else {
			//	We're only interested in newly attached devices if we're waiting for devices...
			
			return
		}
		
		//	Grab device ID
	
		guard let deviceId = notification.userInfo?["DeviceID"] as? NSNumber else {
			self.debugPrint(message: "Device attached, but failed to get ID.")
			
			return
		}
		
		self.debugPrint(message: "Device attached with ID \(deviceId), attempting connection...")
		
		//	Try to connect to it...
		
		self.startTryingToConnectToDevice(id: deviceId)
	}
	
	@objc private func deviceDidDetach(_ notification: NSNotification) {
		guard let detachedDeviceId = notification.userInfo?["DeviceID"] as? NSNumber else {
			return
		}
		
		self.debugPrint(message: "Device with ID \(detachedDeviceId) detached")
		
		switch self.connectionState {
			
			case let .tryingToConnect(deviceId, stop) where deviceId == detachedDeviceId:
				stop()
				
				self.connectionState = .waitingForDevice
			
			case let .connected(deviceId, channel) where deviceId == detachedDeviceId:
				channel.close()
				
				self.connectionState = .waitingForDevice
			
			default: break
		
		}
	}
	
	
	//	MARK: - Frame Channel Delegate
	
	func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType type: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
		return false
	}
	
	func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType type: UInt32, tag: UInt32, payload: PTData!) {
		/* noop, shouldn't be called */
	}
	
	func ioFrameChannel(_ channel: PTChannel!, didEndWithError error: Error!) {
		switch self.connectionState {
			case let .connected(deviceId, _):
				self.debugPrint(message: "Disconnected from device with ID \(deviceId), retrying...")
				
				self.startTryingToConnectToDevice(id: deviceId)
			
			default: break
		}
	}
	
	
	//	MARK: - Connection Initiation
	
	private func startTryingToConnectToDevice(id deviceId: NSNumber) {
		
		func tryToConnectToDevice(id deviceId: NSNumber, completion: @escaping (ConnectionAttemptResult) -> Void) {
			let usbHub = PTUSBHub.shared()
			let channel = PTChannel(delegate: self)!
			
			channel.userInfo = deviceId
			
			channel.connect(toPort: Int32(self.port.rawValue), overUSBHub: usbHub, deviceID: deviceId) {
				potentialError in
				
				DispatchQueue.main.async {
					if let error = potentialError {
						completion(.failure(error))
					} else {
						completion(.success(channel))
					}
				}
			}
		}
		
		var stop = false
		var workItem: DispatchWorkItem?
		
		self.connectionState = .tryingToConnect(deviceId: deviceId, stop: {
			stop = true
			
			workItem?.cancel()
			workItem = nil
		})
		
		tryToConnectToDevice(id: deviceId) {
			result in
			
			if stop {
				//	IT'S TIME TO STOP
				
				return
			}
			
			switch result {
				case .failure:
					let localWorkItem = DispatchWorkItem {
						[weak self] in self?.startTryingToConnectToDevice(id: deviceId)
					}
					
					workItem = localWorkItem
					
					DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: localWorkItem)
				
				case .success(let channel):
					self.debugPrint(message: "Successfully connected to device with ID \(deviceId).")
					
					self.connectionState = .connected(deviceId: deviceId, channel: channel)
			}
		}
	}
	
	
	//	MARK: - Read/Write
	
	func send(data: Data, ofType type: Common.DataType, callback: ((SendAttemptResult) -> Void)? = nil) {
		switch self.connectionState {
			
			case let .connected(_, channel):
				channel.sendFrame(
					ofType: type.rawValue,
					tag: PTFrameNoTag,
					withPayload: (data as NSData).createReferencingDispatchData(),
					callback: {
						potentialError in
						
						if let error = potentialError {
							callback?(.failure(error))
						} else {
							callback?(.success)
						}
					})
			
			default:
				self.debugPrint(message: "Attempted to write while no connection was established. Ignoring...")
				
				callback?(.failure(SendError.triedToSendDataWhileDisconnected))
		
		}
	}

}

extension USBBridge {

	private enum ConnectionState {

		case connected(deviceId: NSNumber, channel: PTChannel)
		case tryingToConnect(deviceId: NSNumber, stop: () -> Void)
		case waitingForDevice

	}

	private enum ConnectionAttemptResult {

		case failure(Error)
		case success(PTChannel)

	}

	enum SendAttemptResult {

		case failure(Error)
		case success

	}
	
	enum SendError: Error {
	
		case triedToSendDataWhileDisconnected
	
	}

}
