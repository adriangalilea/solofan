//
//  MenuBarDefaults.swift
//  SoloFan
//
//  Fork-local: single source of truth for the menu-bar display default.
//

import Foundation

enum MenuBarDefaults {
    /// Persisted value for `statusBarDisplayMode`. Icon-only by default — no
    /// constantly-updating number in the menu bar unless the user opts in.
    static let displayMode = "none"
}
