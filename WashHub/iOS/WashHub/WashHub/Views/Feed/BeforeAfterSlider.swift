import SwiftUI

struct BeforeAfterSlider: View {
    let beforeImages: [FeedImage]
    let afterImages: [FeedImage]
    @State private var sliderPosition: CGFloat = 0.5

    var body: some View {
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
}
