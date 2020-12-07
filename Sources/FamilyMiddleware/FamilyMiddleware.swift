import os.log
import Foundation
import Combine

import SwiftRex

// MARK: - ACTIONS
//sourcery: Prism
public enum FamilyAction {
    case create(String, String)
    case delete
    case update([FamilyInfo.CodingKeys: Any])
    case register(String)
    case stateChanged(FamilyState)
}

// MARK: - STATE
public struct FamilyState: Codable, Equatable {
    public let key: String
    public let value: FamilyInfo
    
    public init(key: String, value: FamilyInfo) {
        self.key = key
        self.value = value
    }
}

public struct FamilyInfo: Codable, Equatable {
    public let displayName: String
    public let members: [String: MemberInfo]?
    public let carpools: [String: CarpoolInfo]?

    public init(
        displayName: String,
        carpools: [String: CarpoolInfo]? = nil,
        members: [String: MemberInfo]? = nil
    )
    {
        self.displayName = displayName
        self.carpools = carpools
        self.members = members
    }
}

extension FamilyInfo {
    public enum CodingKeys: String, CodingKey {
        case displayName
        case members
        case carpools
    }
}

public struct MemberInfo: Codable, Equatable {
    public let type: MemberTypes
}

public enum MemberTypes: String, Codable {
    case guardian
    case child
    case caregiver
}

public struct CarpoolInfo: Codable, Equatable {
    public let participant: Bool
}

// MARK: - ERRORS
public enum FamilyError: Error {
    case familyDecodingError
    case familyEncodingError
    case familyDataNotFoundError
    case familyCreationError
    case familyDeletionError
}

// MARK: - PROTOCOL
public protocol FamilyStorage {
    func register(key: String)
    func create(family: FamilyInfo) -> AnyPublisher<String, FamilyError>
    func update(key: String, params: [String: Any]) -> AnyPublisher<Void, FamilyError>
    func delete(key: String) -> AnyPublisher<Void, FamilyError>
    func familyChangeListener() -> AnyPublisher<FamilyState, FamilyError>
}

// MARK: - MIDDLEWARE

/// The FamilyMiddleware is specifically designed to suit the needs of one application.
///
/// It offers the following :
///   * it registers a key with the data provider (see below),
///   * it provides several facilities to create, update and delete the family entry
///   * it listens to all state changes for the particular key that was registered
/// Any new state change collected from the listener is dispatched as an action
/// so the global state can be modified accordingly.
///
public class FamilyMiddleware: Middleware {
    public typealias InputActionType = FamilyAction
    public typealias OutputActionType = FamilyAction
    public typealias StateType = FamilyState?
    
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "FamilyMiddleware")

    private var output: AnyActionHandler<OutputActionType>? = nil
    private var getState: GetState<StateType>? = nil

    private var provider: FamilyStorage
    
    private var stateChangeCancellable: AnyCancellable?
    private var operationCancellable: AnyCancellable?

    public init(provider: FamilyStorage) {
        self.provider = provider
    }
    
    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        os_log(
            "Receiving context...",
            log: FamilyMiddleware.logger,
            type: .debug
        )
        self.getState = getState
        self.output = output
        self.stateChangeCancellable = provider
            .familyChangeListener()
            .sink { (completion: Subscribers.Completion<FamilyError>) in
                var result: String = "success"
                if case let Subscribers.Completion.failure(err) = completion {
                    result = "failure : " + err.localizedDescription
                }
                os_log(
                    "State change completed with %s.",
                    log: FamilyMiddleware.logger,
                    type: .debug,
                    result
                )
            } receiveValue: { family in
                os_log(
                    "State change receiving value for family : %s...",
                    log: FamilyMiddleware.logger,
                    type: .debug,
                    String(describing: family.key)
                )
                self.output?.dispatch(.stateChanged(family))
            }
    }
    
    public func handle(
        action: InputActionType,
        from dispatcher: ActionSource,
        afterReducer : inout AfterReducer
    ) {
        switch action {
            case let .register(id):
                os_log(
                    "Registering family with id : %s ...",
                    log: FamilyMiddleware.logger,
                    type: .debug,
                    String(describing: id)
                )
                provider.register(key: id)
            case let .create(name, userId):
                operationCancellable = provider
                    .create(
                        family: FamilyInfo(
                            displayName: name,
                            members: [userId: MemberInfo(type: .guardian)]
                        )
                    )
                    .sink { (completion: Subscribers.Completion<FamilyError>) in
                        var result: String = "success"
                        if case let Subscribers.Completion.failure(err) = completion {
                            result = "failure : " + err.localizedDescription
                        }
                        os_log(
                            "Family creation completed with %s.",
                            log: FamilyMiddleware.logger,
                            type: .debug,
                            result
                        )
                    } receiveValue: { [self] familyId in
                        os_log(
                            "Family creation received ack with id : %s",
                            log: FamilyMiddleware.logger,
                            type: .debug,
                            familyId
                        )
                        output?.dispatch(.register(familyId))
                    }
            default:
                os_log(
                    "Not handling this case : %s ...",
                    log: FamilyMiddleware.logger,
                    type: .debug,
                    String(describing: action)
                )
                break
        }
        
        afterReducer = .do { [self] in
            if let state = getState,
               let newState = state() {
                os_log(
                    "Calling afterReducer closure...",
                    log: FamilyMiddleware.logger,
                    type: .debug
                )
                switch action {
                    case .delete:
                        operationCancellable = provider
                            .delete(key: newState.key)
                            .sink { (completion: Subscribers.Completion<FamilyError>) in
                                var result: String = "success"
                                if case let Subscribers.Completion.failure(err) = completion {
                                    result = "failure : " + err.localizedDescription
                                }
                                os_log(
                                    "Family deletion completed with %s.",
                                    log: FamilyMiddleware.logger,
                                    type: .debug,
                                    result
                                )
                            } receiveValue: { _ in
                                os_log(
                                    "Family deletion received ack.",
                                    log: FamilyMiddleware.logger,
                                    type: .debug
                                )
                            }
                    case let .update(params):
                        var paramDict: [String: Any] = [:]
                        params.forEach { key, value in
                            paramDict.updateValue(value, forKey: key.stringValue)
                        }
                        operationCancellable = provider
                            .update(key: newState.key, params: paramDict)
                            .sink { (completion: Subscribers.Completion<FamilyError>) in
                                var result: String = "success"
                                if case let Subscribers.Completion.failure(err) = completion {
                                    result = "failure : " + err.localizedDescription
                                }
                                os_log(
                                    "Family update completed with %s.",
                                    log: FamilyMiddleware.logger,
                                    type: .debug,
                                    result
                                )
                            } receiveValue: { _ in
                                os_log(
                                    "Family update received ack.",
                                    log: FamilyMiddleware.logger,
                                    type: .debug
                                )
                            }
                    default:
                        os_log(
                            "Apparently not handling this case either : %s...",
                            log: FamilyMiddleware.logger,
                            type: .debug,
                            String(describing: action)
                        )
                        break
                }
            }
        }
    }
}
