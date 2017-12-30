//
//  USBBridge.swift
//  iosPlaygrounds+
//
//  Created by Matt Curtis on 12/22/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Foundation

class USBBridge: NSObject, PTChannelDelegate {

	//	MARK: - Properties
	
	private weak var peerChannel: PTChannel?
	
	private weak var serverChannel: PTChannel?
	
	
	let port: Common.Port
	
	var onIncomingData: ((Data, Common.DataType) -> Void)?


	//	MARK: - Init
	
	init(as port: Common.Port, onIncomingData: ((Data, Common.DataType) -> Void)? = nil) {
		self.port = port
		
		super.init()
		
		self.onIncomingData = onIncomingData
		
		//	Start listening on common port...
		
		let channel = PTChannel(delegate: self)!
		
		channel.listen(onPort: in_port_t(self.port.rawValue), iPv4Address: INADDR_LOOPBACK) {
			[weak self] error in
			
			if error != nil {
				self?.debugPrint(message: "Failed to start listening on port \(port.rawValue)")
			} else {
				self?.debugPrint(message: "Listening on port \(port.rawValue)")
				
				self?.serverChannel = channel
			}
		}
	}
	
	deinit {
		self.serverChannel?.close()
	}
	
	
	//	MARK: - Debug
	
	func debugPrint(message: String) {
		#if DEBUG
			print("\(type(of: self)) [On port \(self.port)]: \(message)")
		#endif
	}
	
	
	//	MARK: - Peertalk
	
	func ioFrameChannel(_ channel: PTChannel!, didAcceptConnection otherChannel: PTChannel!, from address: PTAddress!) {
		if channel != self.serverChannel {
			return
		}
		
		self.debugPrint(message: "Connected to Mac!")
		
		self.peerChannel?.cancel()
		
		otherChannel.userInfo = address
		
		self.peerChannel = otherChannel
	}
	
	func ioFrameChannel(_ channel: PTChannel!, shouldAcceptFrameOfType typeInt: UInt32, tag: UInt32, payloadSize: UInt32) -> Bool {
		if Common.DataType(rawValue: typeInt) == nil {
			self.debugPrint(message: "Received unknown frame of type \(typeInt), ignoring...")
			
			return false
		}
		
		return true
	}
	
	func ioFrameChannel(_ channel: PTChannel!, didReceiveFrameOfType typeInt: UInt32, tag: UInt32, payload optionalPayload: PTData?) {
		guard let type = Common.DataType(rawValue: typeInt) else {
			return
		}
		
		var data = Data()
		
		if let payload = optionalPayload {
			data = Data(bytes: payload.data, count: payload.length)
		}
		
		self.onIncomingData?(data, type)
	}
	
	func ioFrameChannel(_ channel: PTChannel!, didEndWithError optionalError: Error!) {
		if let error = optionalError {
			self.debugPrint(message: "\(channel!) ended with error \(error)")
		} else {
			self.debugPrint(message: "\(channel!) disconnected.")
		}
	}

}
