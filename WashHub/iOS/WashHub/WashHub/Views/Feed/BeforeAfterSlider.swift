import SwiftUI

struct BeforeAfterSlider: View {
    let beforeImages: [FeedImage]
    let afterImages: [FeedImage]
    @State private var sliderPosition: CGFloat = 0.5

    private var hasBefore: Bool { !beforeImages.isEmpty }
    private var hasAfter: Bool { !afterImages.isEmpty }

    var body: some View {
        if !hasBefore && !hasAfter {
            // 양쪽 모두 없음 — 단일 placeholder
            bothEmptyPlaceholder
        } else if hasBefore && hasAfter {
            // 둘 다 있음 — 기존 슬라이더
            sliderView
        } else {
            // 한쪽만 있음 — 이미지 + placeholder 나란히
            singleSidePlaceholder
        }
    }

    // MARK: - 양쪽 모두 없을 때
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
        .frame(height: 200)
    }

    // MARK: - 한쪽만 있을 때
    private var singleSidePlaceholder: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack {
                HStack(spacing: 0) {
                    // Before 영역
                    if hasBefore, let url = beforeImages.first?.imageUrl {
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color.theme.surface)
                            }
                        }
                        .frame(width: width / 2, height: 300)
                        .clipped()
                    } else {
                        imagePlaceholder(label: "Before 사진 없음")
                            .frame(width: width / 2, height: 300)
                    }

                    // After 영역
                    if hasAfter, let url = afterImages.first?.imageUrl {
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color.theme.surface)
                            }
                        }
                        .frame(width: width / 2, height: 300)
                        .clipped()
                    } else {
                        imagePlaceholder(label: "After 사진 없음")
                            .frame(width: width / 2, height: 300)
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
        .frame(height: 300)
    }

    // MARK: - 기존 슬라이더 (양쪽 다 있을 때)
    private var sliderView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack {
                // After 이미지 (전체)
                if let afterUrl = afterImages.first?.imageUrl {
                    AsyncImage(url: URL(string: afterUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(Color.theme.surface)
                        }
                    }
                    .frame(width: width, height: 300)
                    .clipped()
                }

                // Before 이미지 (슬라이더로 잘림)
                if let beforeUrl = beforeImages.first?.imageUrl {
                    AsyncImage(url: URL(string: beforeUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(Color.theme.neutral)
                        }
                    }
                    .frame(width: width, height: 300)
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
                    .frame(width: 3, height: 300)
                    .position(x: width * sliderPosition, y: 150)

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
                    .position(x: width * sliderPosition, y: 150)

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
        .frame(height: 300)
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
