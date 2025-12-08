//
//  SavedRepo.swift
//  Newgit
//
//  Created by Ariel Araya-Madrigal on 12/6/25.
//

import Foundation
import SwiftData

@Model
class SavedRepo {
    @Attribute(.unique) var id: UUID
    var name: String
    var path: String
    var lastUpdated: Date

    init(id: UUID = UUID(), name: String, path: String, lastUpdated: Date = Date()) {
        self.id = id
        self.name = name
        self.path = path
        self.lastUpdated = lastUpdated
    }
}

