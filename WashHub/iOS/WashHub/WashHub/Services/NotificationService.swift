import Foundation
import Combine
import Supabase

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false

    private let pageSize = 20

    private let notificationSelect = "*, sender:profiles!fk_notifications_sender_profile(id, nickname, avatar_url)"

    // MARK: - 알림 목록 조회
    func loadNotifications(offset: Int = 0, forceRefresh: Bool = false) async {
        isLoading = true
        do {
            let persistNotifications: [AppNotification] = try await supabase
                .from("notifications")
                .select(notificationSelect)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value

            if offset == 0 || forceRefresh {
                notifications = persistNotifications
            } else {
                notifications.append(contentsOf: persistNotifications)
            }
        } catch {
            print("Notification load error: \(error)")
        }
        isLoading = false
    }

    // MARK: - 안 읽은 알림 수 조회
    func fetchUnreadCount() async {
        do {
            struct IdOnly: Codable { let id: String }
            let persistUnread: [IdOnly] = try await supabase
                .from("notifications")
                .select("id")
                .eq("is_read", value: false)
                .execute()
                .value

            unreadCount = persistUnread.count
        } catch {
            print("Unread count error: \(error)")
        }
    }

    // MARK: - 단일 알림 읽음 처리
    func markAsRead(notificationId: String) async {
        do {
            try await supabase
                .from("notifications")
                .update([
                    "is_read": "true",
                    "read_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: notificationId)
                .execute()

            // 로컬 상태 업데이트
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[index].isRead = true
            }
            unreadCount = max(0, unreadCount - 1)
        } catch {
            print("Mark as read error: \(error)")
        }
    }

    // MARK: - 전체 읽음 처리
    func markAllAsRead() async {
        do {
            try await supabase
                .from("notifications")
                .update([
                    "is_read": "true",
                    "read_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("is_read", value: false)
                .execute()

            // 로컬 상태 전체 업데이트
            for i in notifications.indices {
                notifications[i].isRead = true
            }
            unreadCount = 0
        } catch {
            print("Mark all as read error: \(error)")
        }
    }
}
