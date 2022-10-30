//
//  DarkTheme.swift
//  Pogo
//
//  Created by Yaniv Hasbani on 01/11/2022.
//

import UIKit

struct HexColorError: Error {
  
}

struct DarkTheme {  
  static var backgroundColour: UIColor {
    UIColor(dynamicProvider: { traitCollection in
      if traitCollection.userInterfaceStyle == .dark {
        return UIColor(hex:0x0E1013)
      } else {
        return UIColor(hex:0x0E1013)
      }
    })
  }
}

extension UIColor {
  convenience init(red: Int, green: Int, blue: Int) {
    assert(red >= 0 && red <= 255, "Invalid red component")
    assert(green >= 0 && green <= 255, "Invalid green component")
    assert(blue >= 0 && blue <= 255, "Invalid blue component")
    
    self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
  }
  
  convenience init(hex: Int) {
    self.init(
      red: (hex >> 16) & 0xFF,
      green: (hex >> 8) & 0xFF,
      blue: hex & 0xFF
    )
  }
}
