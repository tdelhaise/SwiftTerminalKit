
//
//  MenuCommandDelegate.swift
//  SwiftTerminalKit
//
//  Created by Thierry on 2024-07-11.
//

import Foundation

/// A protocol for views that can handle menu commands.
public protocol MenuCommandDelegate {
    func handleMenuCommand(_ commandId: Int) -> Bool
}
