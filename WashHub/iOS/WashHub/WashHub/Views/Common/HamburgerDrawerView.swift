import SwiftUI

/// 햄버거 드로어에서 발생하는 진입 액션 (REDESIGN_BRIEF 6.2 / 6.3)
enum DrawerDestination {
    // 빅 카드 4개
    case washIndex      // 오늘 세차할까? → 세차 예측
    case map            // 어디서 세차하지? → 세차장 탭
    case equipment      // 뭐로 세차하지? → 세차용품 탭
    case myCarRecord    // 내 세차 기록 → 내차 탭

    // 모든 메뉴 리스트
    case feed           // 커뮤니티 피드
    case liked          // 좋아요한 글
    case following      // 팔로잉
    case nextWash       // 다음 세차 일정
    case routines       // 추천 루틴
    case myCarManage    // 내 차량 관리
    case badges         // 내 뱃지

    // 기타
    case search
    case settings
    case help
    case logout
}

/// v2 햄버거 드로어 — 옵션 B (빅 카드 + 리스트)
///
/// 부모(`HomeTabView`)의 ZStack 최상단 오버레이로 배치한다.
/// `isOpen` 바인딩으로 슬라이드 인/아웃하며, 백드롭 탭/닫기 버튼은 `onClose`,
/// 카드·메뉴 선택은 `onGo(_:)` 로 전달한다.
struct HamburgerDrawerView: View {
    let isOpen: Bool
    let userName: String
    let onClose: () -> Void
    let onGo: (DrawerDestination) -> Void

    /// 패널 폭 — 화면의 약 88%
    private func panelWidth(_ total: CGFloat) -> CGFloat { total * 0.88 }

    var body: some View {
        GeometryReader { geo in
            let width = panelWidth(geo.size.width)
            ZStack(alignment: .leading) {
                // 백드롭
                Color.black
                    .opacity(isOpen ? 0.45 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(isOpen)
                    .onTapGesture { onClose() }

                // 패널
                panel(width: width)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .background(Color.theme.surface)
                    .offset(x: isOpen ? 0 : -(width + 24))
                    .shadow(color: .black.opacity(isOpen ? 0.18 : 0), radius: 24, x: 8, y: 0)
            }
            .animation(.easeOut(duration: 0.28), value: isOpen)
        }
        .ignoresSafeArea()
        .allowsHitTesting(isOpen)
    }

    // MARK: - 패널 본문

    private func panel(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            header
            searchBar
                .padding(.horizontal, 22)
                .padding(.top, 14)
            bigCards
                .padding(.horizontal, 22)
                .padding(.top, 16)

            ScrollView {
                menuList
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
            }

            footer
        }
        .padding(.top, 56)
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("안녕하세요 👋")
                    .font(.appSmallBold)
                    .foregroundColor(.theme.textSecondary)
                Text("\(userName)님")
                    .font(.appHeadline1)
                    .foregroundColor(.theme.textPrimary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.theme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.theme.surfaceLowest)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
    }

    // MARK: - 검색

    private var searchBar: some View {
        Button { onGo(.search) } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.theme.textDisabled)
                Text("무엇이든 찾아보세요")
                    .font(.appCaption)
                    .foregroundColor(.theme.textDisabled)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.theme.surfaceLowest)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 빅 카드 4개

    private var bigCards: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            bigCard(icon: "cloud.sun.fill", title: "오늘 세차할까?", hint: "세차 예측 보기",
                    bg: Color.theme.accent, fg: Color.theme.onAccent, dest: .washIndex)
            bigCard(icon: "map.fill", title: "어디서 세차하지?", hint: "근처 세차장",
                    bg: Color.theme.primary, fg: Color.theme.onPrimary, dest: .map)
            bigCard(icon: "drop.fill", title: "뭐로 세차하지?", hint: "케미컬 · 루틴",
                    bg: Color.theme.surfaceLowest, fg: Color.theme.textPrimary, dest: .equipment)
            bigCard(icon: "clock.arrow.circlepath", title: "내 세차 기록", hint: "기록 보기",
                    bg: Color.theme.surfaceLowest, fg: Color.theme.textPrimary, dest: .myCarRecord)
        }
    }

    private func bigCard(icon: String, title: String, hint: String,
                         bg: Color, fg: Color, dest: DrawerDestination) -> some View {
        Button { onGo(dest) } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 68))
                    .foregroundColor(fg)
                Spacer(minLength: 14)
                Text(title)
                    .font(.appCaptionBold)
                    .foregroundColor(fg)
                Text(hint)
                    .font(.appLabelSmall)
                    .foregroundColor(fg.opacity(0.65))
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(1, contentMode: .fit)
            .padding(16)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            // v2 가독성(B안) — 고스트 보더 + 옅은 그림자로 밝은 배경에서 카드 분리
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.theme.outlineVariant, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(DrawerPressStyle())
    }

    // MARK: - 모든 메뉴 리스트

    private var menuList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("모든 메뉴")
                .font(.appLabelSmall)
                .fontWeight(.heavy)
                .kerning(1.4)
                .foregroundColor(.theme.textSecondary)
                .padding(.bottom, 4)

            menuRow(icon: "rectangle.stack.fill", label: "커뮤니티 피드", dest: .feed)
            menuRow(icon: "heart.fill", label: "좋아요한 글", dest: .liked)
            menuRow(icon: "person.2.fill", label: "팔로잉", dest: .following)
            menuRow(icon: "calendar", label: "다음 세차 일정", sub: "다가오는 세차일", dest: .nextWash)
            menuRow(icon: "list.bullet.clipboard.fill", label: "추천 루틴", sub: "초보용 4가지 코스", dest: .routines)
            menuRow(icon: "car.fill", label: "내 차량 관리", dest: .myCarManage)
            menuRow(icon: "rosette", label: "내 뱃지", dest: .badges)
        }
    }

    private func menuRow(icon: String, label: String, sub: String? = nil,
                         dest: DrawerDestination) -> some View {
        Button { onGo(dest) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.theme.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.appCaptionMedium)
                        .foregroundColor(.theme.textPrimary)
                    if let sub {
                        Text(sub)
                            .font(.appSmall)
                            .foregroundColor(.theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.theme.textDisabled)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 푸터

    private var footer: some View {
        HStack(spacing: 0) {
            footerItem(icon: "gearshape", label: "설정", dest: .settings)
            footerItem(icon: "questionmark.circle", label: "도움말", dest: .help)
            footerItem(icon: "rectangle.portrait.and.arrow.right", label: "로그아웃", dest: .logout)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 32)
    }

    private func footerItem(icon: String, label: String, dest: DrawerDestination) -> some View {
        Button { onGo(dest) } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.appSmall)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.theme.onSurfaceVariant)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 카드 프레스 애니메이션

private struct DrawerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    HamburgerDrawerView(
        isOpen: true,
        userName: "재가입농장",
        onClose: {},
        onGo: { _ in }
    )
}
