// Generated using Sourcery 1.0.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

extension FamilyAction {
    public var create: (String, String)? {
        get {
            guard case let .create(associatedValue0, associatedValue1) = self else { return nil }
            return (associatedValue0, associatedValue1)
        }
        set {
            guard case .create = self, let newValue = newValue else { return }
            self = .create(newValue.0, newValue.1)
        }
    }

    public var isCreate: Bool {
        self.create != nil
    }

    public var delete: Void? {
        get {
            guard case .delete = self else { return nil }
            return ()
        }
    }

    public var isDelete: Bool {
        self.delete != nil
    }

    public var update: [FamilyInfo.CodingKeys: Any]? {
        get {
            guard case let .update(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .update = self, let newValue = newValue else { return }
            self = .update(newValue)
        }
    }

    public var isUpdate: Bool {
        self.update != nil
    }

    public var register: String? {
        get {
            guard case let .register(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .register = self, let newValue = newValue else { return }
            self = .register(newValue)
        }
    }

    public var isRegister: Bool {
        self.register != nil
    }

    public var stateChanged: FamilyState? {
        get {
            guard case let .stateChanged(associatedValue0) = self else { return nil }
            return (associatedValue0)
        }
        set {
            guard case .stateChanged = self, let newValue = newValue else { return }
            self = .stateChanged(newValue)
        }
    }

    public var isStateChanged: Bool {
        self.stateChanged != nil
    }

}
