//
//  KeepAlive.swift
//  iosPlaygrounds+
//
//  Created by Matt Curtis on 12/23/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Foundation
import AVFoundation

///	Exploits AVAudioPlayer and AVAudioSession to avoid suspension when backgrounded.

struct KeepAlive {
	
	//	MARK: - Properties
	
	private static var player: AVAudioPlayer?
	
	private static var observer: NSObjectProtocol?
	
	
	//	MARK: - Enable/Disable
	
	static func enable() {
		//	Avoid interruption:
		
		self.observer = NotificationCenter.default.addObserver(
			forName: .AVAudioSessionInterruption,
			object: AVAudioSession.sharedInstance(),
			queue: nil,
			using: {
				notification in
				
				if
					let interruptionTypeCode = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue,
					AVAudioSessionInterruptionType(rawValue: interruptionTypeCode) == .ended
				{
					//	Restart audio:
					
					self.playAudio()
				}
			}
		)
		
		//	Start playing:
		
		self.playAudio()
	}
	
	static func disable() {
		if let observer = self.observer {
			NotificationCenter.default.removeObserver(observer as Any)
		}
		
		self.player?.stop()
	}
	
	
	//	MARK: - Play Audio
	
	@discardableResult
	private static func playAudio() -> Bool {
		do {
			let session = AVAudioSession.sharedInstance()
			
			try session.setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
			try session.setActive(true)
			
			guard let audioPath = Bundle.main.path(forResource: "silent", ofType: "wav") else {
				fatalError("silent.wav is missing!")
			}
			
			let silentSound = URL(fileURLWithPath: audioPath)
			let player = try AVAudioPlayer(contentsOf: silentSound)
			
			player.numberOfLoops = -1
			player.volume = 0.01
			
			guard player.play() else {
				print("Failed to play wav! :(")
				
				return false
			}
			
			self.player = player
		} catch {
			print(error)
			
			return false
		}
		
		return true
	}
	
}
