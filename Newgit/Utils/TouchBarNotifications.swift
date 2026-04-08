// TouchBarNotifications.swift
// Small extension to centralize Notification.Name constants used by the Touch Bar buttons

import Foundation

extension Notification.Name {
    static let newgitCloneRepo = Notification.Name("Newgit.CloneRepo")
    static let newgitAddNewRepo = Notification.Name("Newgit.AddNewRepo")
    static let newgitAddExistingRepo = Notification.Name("Newgit.AddExistingRepo")
    static let newgitIntentCloneRepo = Notification.Name("Newgit.Intent.CloneRepo")
    static let newgitIntentAddNewRepo = Notification.Name("Newgit.Intent.AddNewRepo")
    static let newgitIntentAddExistingRepo = Notification.Name("Newgit.Intent.AddExistingRepo")
    static let newgitOpenRepository = Notification.Name("Newgit.OpenRepository")
    static let newgitOpenIssues = Notification.Name("Newgit.OpenIssues")
    static let newgitOpenRelease = Notification.Name("Newgit.OpenRelease")
    static let newgitOpenIssuesInSelectedRepo = Notification.Name("Newgit.OpenIssuesInSelectedRepo")
    static let newgitOpenReleaseInSelectedRepo = Notification.Name("Newgit.OpenReleaseInSelectedRepo")
}
