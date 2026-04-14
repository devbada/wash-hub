import SwiftUI
import Supabase

// MARK: - 알림 센터
struct NotificationListView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var notificationService = NotificationService.shared
    @State private var currentOffset = 0
    @State private var navigatedFeedId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            if notificationService.isLoading && notificationService.notifications.isEmpty {
                ProgressView().tint(.theme.secondary)
            } else if notificationService.notifications.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notificationService.notifications) { notification in
                            NotificationRow(notification: notification) {
                                Task {
                                    await notificationService.markAsRead(notificationId: notification.id)
                                }
                                // LIKE, COMMENT → 해당 피드로 이동
                                if (notification.type == .LIKE || notification.type == .COMMENT),
                                   let refId = notification.referenceId {
                                    navigatedFeedId = refId
                                }
                            }
                            .onAppear {
                                // 무한 스크롤
                                if notification.id == notificationService.notifications.last?.id {
                                    currentOffset += 20
                                    Task {
                                        await notificationService.loadNotifications(offset: currentOffset)
                                    }
                                }
                            }

                            Divider()
                                .background(Color.theme.border)
                                .padding(.leading, 60)
                        }
                    }
                }
                .refreshable {
                    currentOffset = 0
                    await notificationService.loadNotifications(forceRefresh: true)
                    await notificationService.fetchUnreadCount()
                }
            }
        }
        // 프로그래밍 방식 네비게이션 — 알림 탭 시 피드 상세로 이동
        .background(
            NavigationLink(
                destination: Group {
                    if let feedId = navigatedFeedId {
                        FeedDetailView(feedId: feedId)
                            .environmentObject(authManager)
                    }
                },
                isActive: Binding(
                    get: { navigatedFeedId != nil },
                    set: { if !$0 { navigatedFeedId = nil } }
                )
            ) { EmptyView() }
            .hidden()
        )
        .navigationTitle("알림")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !notificationService.notifications.isEmpty {
                    Button {
                        Task { await notificationService.markAllAsRead() }
                    } label: {
                        Text("모두 읽음")
                            .font(.appSmall)
                            .foregroundColor(.theme.secondary)
                    }
                    .disabled(notificationService.unreadCount == 0)
                }
            }
        }
        .task {
            await notificationService.loadNotifications()
            await notificationService.fetchUnreadCount()
        }
    }

    // MARK: - 빈 화면
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(.theme.textDisabled)
            Text("알림이 없습니다")
                .font(.appHeadline3)
                .foregroundColor(.theme.textSecondary)
            Text("새로운 활동이 있으면 여기에 표시됩니다")
                .font(.appCaption)
                .foregroundColor(.theme.textDisabled)
        }
    }
}

// MARK: - 알림 Row
struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 발신자 아바타 or 타입 아이콘
                notificationIcon

                VStack(alignment: .leading, spacing: 4) {
                    // 메시지
                    Text(notification.message)
                        .font(.appBody)
                        .foregroundColor(notification.isRead ? .theme.textSecondary : .theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // 시간
                    Text(relativeTime(from: notification.createdAt))
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                }

                Spacer()

                // 안 읽음 표시
                if !notification.isRead {
                    Circle()
                        .fill(Color.theme.secondary)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notification.isRead ? Color.clear : Color.theme.secondary.opacity(0.05))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 알림 아이콘
    @ViewBuilder
    private var notificationIcon: some View {
        if let sender = notification.senderProfile {
            // 발신자가 있으면 아바타 + 타입 뱃지
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: sender.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.theme.surfaceHigh)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.theme.textDisabled)
                            )
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                // 타입 뱃지
                Image(systemName: notification.type.iconName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(iconColor)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
            .frame(width: 40, height: 40)
        } else {
            // 시스템 알림 — 아이콘만
            Image(systemName: notification.type.iconName)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .LIKE: return .pink
        case .COMMENT: return .theme.secondary
        case .FOLLOW: return .theme.tertiary
        case .SYSTEM: return .theme.textSecondary
        case .WASH_REMINDER: return .theme.secondary
        }
    }

    // MARK: - 상대 시간 표시
    private func relativeTime(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // fractionalSeconds 실패 시 fallback
        guard let date = formatter.date(from: dateString)
            ?? ISO8601DateFormatter().date(from: dateString) else {
            return dateString.prefix(10).description
        }

        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "방금" }
        if interval < 3600 { return "\(Int(interval / 60))분 전" }
        if interval < 86400 { return "\(Int(interval / 3600))시간 전" }
        if interval < 604800 { return "\(Int(interval / 86400))일 전" }
        return dateString.prefix(10).description
    }
}
