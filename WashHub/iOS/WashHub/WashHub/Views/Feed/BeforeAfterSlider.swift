import SwiftUI

struct BeforeAfterSlider: View {
    let beforeImages: [FeedImage]
    let afterImages: [FeedImage]
    @State private var sliderPosition: CGFloat = 0.5

    private var hasBefore: Bool { !beforeImages.isEmpty }
    private var hasAfter: Bool { !afterImages.isEmpty }

    /// 컨테이너 가로:세로 비율 — After 우선, Before fallback, 둘 다 없거나 정보 없으면 4:5(세로)
    /// 한 손 촬영이 많아 세로 사진이 다수이므로 legacy/미상은 세로 우선
    private var containerAspectRatio: CGFloat {
        let primary = afterImages.first?.aspectRatio ?? beforeImages.first?.aspectRatio
        return primary ?? (4.0 / 5.0)  // 4:5 portrait fallback
    }

    var body: some View {
        if !hasBefore && !hasAfter {
            // 양쪽 모두 없음 — 단일 placeholder
            bothEmptyPlaceholder
        } else if hasBefore && hasAfter {
            // 둘 다 있음 — 슬라이더 (After 비율 기준)
            sliderView
        } else {
            // 한쪽만 있음 — 이미지 + placeholder 나란히
            singleSidePlaceholder
        }
    }

    // MARK: - 양쪽 모두 없을 때 (정보 없으니 placeholder 만 — 4:5)
    private var bothEmptyPlaceholder: some View {
        ZStack {
            Rectangle().fill(Color.theme.surfaceLow)
            VStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(.theme.textDisabled)
                Text("Before / After 사진 없음")
                    .font(.appCaption)
                    .foregroundColor(.theme.textDisabled)
            }
        }
        .aspectRatio(4.0/5.0, contentMode: .fit)
    }

    // MARK: - 한쪽만 있을 때
    private var singleSidePlaceholder: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                HStack(spacing: 0) {
                    // Before 영역
                    if hasBefore, let url = beforeImages.first?.imageUrl {
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                Rectangle().fill(Color.theme.surface)
                            }
                        }
                        .frame(width: width / 2, height: height)
                        .clipped()
                    } else {
                        imagePlaceholder(label: "Before 사진 없음")
                            .frame(width: width / 2, height: height)
                    }

                    // After 영역
                    if hasAfter, let url = afterImages.first?.imageUrl {
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            default:
                                Rectangle().fill(Color.theme.surface)
                            }
                        }
                        .frame(width: width / 2, height: height)
                        .clipped()
                    } else {
                        imagePlaceholder(label: "After 사진 없음")
                            .frame(width: width / 2, height: height)
                    }
                }

                // Before / After 라벨
                VStack {
                    HStack {
                        Text("Before")
                            .font(.appLabel)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(12)

                        Spacer()

                        Text("After")
                            .font(.appLabel)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(12)
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(containerAspectRatio, contentMode: .fit)
    }

    // MARK: - 슬라이더 (양쪽 다 있을 때)
    private var sliderView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // After 이미지 (전체)
                if let afterUrl = afterImages.first?.imageUrl {
                    AsyncImage(url: URL(string: afterUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            Rectangle().fill(Color.theme.surface)
                        }
                    }
                    .frame(width: width, height: height)
                    .clipped()
                }

                // Before 이미지 (슬라이더로 잘림)
                if let beforeUrl = beforeImages.first?.imageUrl {
                    AsyncImage(url: URL(string: beforeUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            Rectangle().fill(Color.theme.neutral)
                        }
                    }
                    .frame(width: width, height: height)
                    .clipped()
                    .mask(
                        HStack {
                            Rectangle()
                                .frame(width: width * sliderPosition)
                            Spacer(minLength: 0)
                        }
                    )
                }

                // 슬라이더 라인
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 3, height: height)
                    .position(x: width * sliderPosition, y: height / 2)

                // 슬라이더 핸들
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .shadow(radius: 4)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.theme.primary)
                    )
                    .position(x: width * sliderPosition, y: height / 2)

                // Before / After 라벨
                VStack {
                    HStack {
                        Text("Before")
                            .font(.appLabel)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(12)

                        Spacer()

                        Text("After")
                            .font(.appLabel)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                            .padding(12)
                    }
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        sliderPosition = max(0.05, min(value.location.x / width, 0.95))
                    }
            )
        }
        .aspectRatio(containerAspectRatio, contentMode: .fit)
        .contentShape(Rectangle())
    }

    // MARK: - Placeholder 컴포넌트
    private func imagePlaceholder(label: String) -> some View {
        ZStack {
            Rectangle().fill(Color.theme.surfaceLow)
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(.theme.textDisabled)
                Text(label)
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }
        }
    }
}
