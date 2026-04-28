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
    static let newgitShowPullRequestsInSelectedRepo = Notification.Name("Newgit.ShowPullRequestsInSelectedRepo")
    static let newgitShowPushInSelectedRepo = Notification.Name("Newgit.ShowPushInSelectedRepo")
    static let newgitPullInSelectedRepo = Notification.Name("Newgit.PullInSelectedRepo")
    static let newgitShowStashInSelectedRepo = Notification.Name("Newgit.ShowStashInSelectedRepo")
    static let newgitShowCreatePullRequestInSelectedRepo = Notification.Name("Newgit.ShowCreatePullRequestInSelectedRepo")
    static let newgitCreateIssue = Notification.Name("Newgit.CreateIssue")
    static let newgitCreateIssueInSelectedRepo = Notification.Name("Newgit.CreateIssueInSelectedRepo")
    static let newgitRefreshSelectedRepo = Notification.Name("Newgit.RefreshSelectedRepo")
    static let newgitOpenFinderInSelectedRepo = Notification.Name("Newgit.OpenFinderInSelectedRepo")
    static let newgitOpenTerminalInSelectedRepo = Notification.Name("Newgit.OpenTerminalInSelectedRepo")
    static let newgitOpenGitHubInSelectedRepo = Notification.Name("Newgit.OpenGitHubInSelectedRepo")
}
