//
// Wire
// Copyright (C) 2022 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import UserNotifications
import WireTransport

@available(iOS 15, *)
final class Job: NSObject, Loggable {

    // MARK: - Types

    enum InitializationError: Error {

        case invalidEnvironment

    }

    typealias PushPayload = (userID: UUID, eventID: UUID)

    // MARK: - Properties

    private let request: UNNotificationRequest
    private let userID: UUID
    private let eventID: UUID

    private let environment: BackendEnvironmentProvider = BackendEnvironment.shared
    private let networkSession: NetworkSession
    private let accessAPIClient: AccessAPIClient
    private let notificationsAPIClient: NotificationsAPIClient

    // MARK: - Life cycle

    init(request: UNNotificationRequest) throws {
        self.request = request
        (userID, eventID) = try Self.pushPayload(from: request)
        networkSession = try NetworkSession(userID: userID)
        accessAPIClient = AccessAPIClient(networkSession: networkSession)
        notificationsAPIClient = NotificationsAPIClient(networkSession: networkSession)
        super.init()
    }

    // MARK: - Methods

    func execute() async throws -> UNNotificationContent {
        logger.trace("\(self.request.identifier): executing job...")
        logger.info("\(self.request.identifier): request is for user (\(self.userID)) and event (\(self.eventID)")

        guard isUserAuthenticated else {
            throw NotificationServiceError.userNotAuthenticated
        }

        networkSession.accessToken = try await fetchAccessToken()

        guard let event = try await fetchEvent(eventID: eventID) else {
            throw NotificationServiceError.noEvent
        }

        switch event.type {
        case .conversationOtrMessageAdd:
            logger.trace("\(self.request.identifier): returning notification for new message")
            let content = UNMutableNotificationContent()
            content.body = "You received a new message"
            return content

        default:
            logger.trace("\(self.request.identifier): ignoring event of type: \(String(describing: event.type))")
            return .empty
        }
    }

    private class func pushPayload(from request: UNNotificationRequest) throws -> PushPayload {
        guard
            let notificationData = request.content.userInfo["data"] as? [String: Any],
            let userIDString = notificationData["user"] as? String,
            let userID = UUID(uuidString: userIDString),
            let data = notificationData["data"] as? [String: Any],
            let eventIDString = data["id"] as? String,
            let eventID = UUID(uuidString: eventIDString)
        else {
            throw NotificationServiceError.malformedPushPayload
        }

        return (userID, eventID)
    }

    private var isUserAuthenticated: Bool {
        return networkSession.isAuthenticated
    }

    private func fetchAccessToken() async throws -> AccessToken {
        logger.trace("\(self.request.identifier): fetching access token")
        return try await accessAPIClient.fetchAccessToken()
    }

    private func fetchEvent(eventID: UUID) async throws -> ZMUpdateEvent? {
        logger.trace("\(self.request.identifier): fetching event (\(eventID))")
        return try await notificationsAPIClient.fetchEvent(eventID: eventID)
    }

}
