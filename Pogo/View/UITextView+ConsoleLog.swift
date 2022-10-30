//
//  UITextView+ConsoleLog.swift
//  Pogo
//
//  Created by Yaniv Hasbani on 01/11/2022.
//

import UIKit

extension NSAttributedString {
  private static let consoleFontSize = 16.0
  private static let consoleLogColor = UIColor.white
  private static let consoleErrorColor = UIColor.red
  
  var range: NSRange {
    (self.string as NSString).range(of: self.string)
  }
  
  static func error(_ error: String) -> NSAttributedString {
    return self._log(NSAttributedString(string:error), NSAttributedString.consoleErrorColor)
  }
  
  static func log(_ log: String) -> NSAttributedString {
    return self._log(NSAttributedString(string:log))
  }
  
  private static func _log(_ log: NSAttributedString,
                           _ color: UIColor = NSAttributedString.consoleLogColor) -> NSAttributedString {
    let mutableLog = NSMutableAttributedString(attributedString: log)
    let myAttribute = [
      NSAttributedString.Key.font: UIFont.systemFont(ofSize: self.consoleFontSize),
      NSAttributedString.Key.foregroundColor: color,
    ]
    mutableLog.addAttributes(myAttribute, range: log.range)
    
    return mutableLog
  }
}

extension UITextView {
  func error(_ error: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      
      let coloredLog = NSAttributedString.error(error + "\n")
      let existingText = NSMutableAttributedString(attributedString: self.attributedText)
      existingText.append(coloredLog)
      
      self.attributedText = existingText
    }
  }
  
  func log(_ log: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        return
      }
      
      let coloredLog = NSAttributedString.log(log + "\n")
      let existingText = NSMutableAttributedString(attributedString: self.attributedText)
      existingText.append(coloredLog)
      
      self.attributedText = existingText
    }
  }
  
  static func +(textView: UITextView, _ textToAppend: NSAttributedString) { // 1
    let text: NSMutableAttributedString = NSMutableAttributedString()
    if let existingText = textView.attributedText {
      text.append(existingText)
    }
    text.append(textToAppend)
    
    textView.attributedText = text
  }
}
