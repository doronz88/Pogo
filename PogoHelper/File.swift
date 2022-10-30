//
//  file.swift
//  Pogo
//
//  Created by Yaniv Hasbani on 01/11/2022.
//

import Foundation
import System

@objc public class File: NSObject {
  enum FileError: Error, CustomStringConvertible {
    case copyError(_ osError: String)
    case chmodError(_ osError: String)
    case chownError(_ osError: String)
    
    var description: String {
      switch self {
      case .copyError(let osError):
        return "copyError\n\(osError)"
      case .chmodError(let osError):
        return "chmodError\n\(osError)"
      case .chownError(let osError):
        return "chownError\n\(osError)"
      }
    }
  }
  
  private let filePath: String
  
  init(_ filePath: String) {
    self.filePath = filePath
  }
  
  static func createFile(from fromFilePath: String, at atFilePath: String, mode: mode_t = 0o4755,
                         uid: uid_t = 0, gid: gid_t = 0) throws {
    let copiedFileHandle = try File.copy(fromFilePath, atFilePath)
    
    try copiedFileHandle.chmod(mode)
    try copiedFileHandle.chown(uid, gid)
  }
  
  convenience init(at filePath: String, mode: mode_t = 0o4755,
                   uid: uid_t = 0, gid: gid_t = 0) throws {
    self.init(filePath)
    
    try self.chmod(mode)
    try self.chown(uid, gid)
  }
  
  static func copy(_ fromPath: String, _ toPath: String) throws -> File {
    do {
      if FileManager.default.fileExists(atPath: toPath) {
        do {
          try FileManager.default.removeItem(atPath: toPath)
        }
        
        try FileManager.default.copyItem(atPath: fromPath, toPath: toPath)
      }
      
      return File(toPath)
    } catch {
      throw FileError.copyError("error copying file from \(fromPath) to \(toPath).\nerror = \(error)\n")
    }
  }
  
  func copy(_ toPath: String) throws -> File {
    return try File.copy(self.filePath, toPath)
  }

  func chmod(_ mode: mode_t) throws {
    try self.filePath.withCString { cStringFilePath in
      let result = Darwin.chmod(cStringFilePath, mode)
      if (result != KERN_SUCCESS) {
        throw FileError.chmodError("path = \(self.filePath)\nerror = \(result)\n")
      }
    }
  }
  
  func chown(_ uid: uid_t, _ gid: gid_t) throws {
    try self.filePath.withCString { cStringFilePath in
      let result = Darwin.chown(cStringFilePath, uid, gid)
      if (result != KERN_SUCCESS) {
        throw FileError.chownError("path = \(self.filePath)\nerror = \(result)\n")
      }
    }
  }
}
