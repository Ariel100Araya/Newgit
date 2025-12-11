// TouchBarNotifications.swift
// Small extension to centralize Notification.Name constants used by the Touch Bar buttons

import Foundation

extension Notification.Name {
    static let newgitCloneRepo = Notification.Name("Newgit.CloneRepo")
    static let newgitAddNewRepo = Notification.Name("Newgit.AddNewRepo")
    static let newgitAddExistingRepo = Notification.Name("Newgit.AddExistingRepo")
}
