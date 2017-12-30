//
//  Common.swift
//  Playgrounds+
//
//  Created by Matt Curtis on 12/22/17.
//  Copyright © 2017 Matt Curtis. All rights reserved.
//

import Foundation

struct Common {

	enum Port: UInt32 {
	
		//	Really high port numbers (I only test > 9000) have odd behaviors, use lower ones
	
		case mainApp = 2341 // derived from the example port
		case uiTestApp
	
	}
	
	
	enum DataType: UInt32 {
	
		//	Must be >= 100
	
		case fileWrite = 100
		case fileDelete
		
		case emptyPlayground
		
		case runMyCode
	
	}
	
	
	struct FileWriteRequest {
	
		var filePath: String

		var data: Data
	
	}

}

extension Common.FileWriteRequest {
	
	init?(decodedFrom data: Data) {
		var cursor: Int = 0
		
		func consumeDataAndAdvanceCursor(next: Int) -> Data {
			let subData = data.subdata(in: cursor..<cursor+next)
			
			cursor += next
			
			return subData
		}
		
		//	File Path
		
		do {
			let utf8LengthData = consumeDataAndAdvanceCursor(next: MemoryLayout<UInt>.size)
			
			let utf8Length: UInt = utf8LengthData.withUnsafeBytes { $0.pointee }
			
			let utf8Data = consumeDataAndAdvanceCursor(next: Int(utf8Length))
			
			guard let filePath = String(bytes: utf8Data, encoding: .utf8) else {
				return nil
			}
			
			self.filePath = filePath
		}
		
		//	Data
		
		self.data = data.subdata(in: cursor..<data.endIndex)
	}

	func encodeAsData() -> Data? {
		var data = Data()
		
		guard let fileNameAsData = self.filePath.data(using: .utf8) else {
			return nil
		}
		
		var fileNameLength = UInt(fileNameAsData.count)
		
		data += Data(
			bytes: &fileNameLength,
			count: MemoryLayout.size(ofValue: fileNameLength)
		)
		
		data += fileNameAsData
		
		data += self.data
		
		return data
	}

}
