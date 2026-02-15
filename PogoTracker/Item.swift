//
//  Item.swift
//  PogoTracker
//
//  Created by Matthéo Ribeiro on 2/15/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
