import SwiftUI

// MARK: - 피드 검색 결과 행
struct FeedSearchRow: View {
    let feed: Feed

    var body: some View {
        HStack(spacing: 12) {
            // 썸네일
            if let url = feed.thumbnailUrl, !url.isEmpty {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.theme.surfaceHigh
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.theme.surfaceHigh)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.theme.textDisabled)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                // 타입 라벨
                HStack(spacing: 4) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 10))
                    Text("피드")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.theme.secondary)

                // 본문 발췌 (제목은 deprecated)
                Text(feed.content?.prefix(40).description ?? "세차 피드")
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                // 작성자 + 날짜
                HStack(spacing: 4) {
                    Text(feed.profiles?.displayName ?? "사용자")
                        .font(.appSmall)
                    Text("·")
                    Text(String(feed.createdAt.prefix(10)))
                        .font(.appSmall)
                }
                .foregroundColor(.theme.textDisabled)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - 케미컬 검색 결과 행
struct EquipmentSearchRow: View {
    let equipment: Equipment

    var body: some View {
        HStack(spacing: 12) {
            // 이미지 — 검색 결과 행도 작은 사이즈이므로 썸네일 우선
            if let url = equipment.displayThumbnailUrl, !url.isEmpty {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Color.theme.surfaceHigh
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.theme.surfaceHigh)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "drop.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.theme.textDisabled)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.circle")
                        .font(.system(size: 10))
                    Text("케미컬")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.theme.tertiary)

                Text(equipment.name)
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                if let desc = equipment.description, !desc.isEmpty {
                    Text(desc)
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - 세차장 검색 결과 행
struct CarWashSearchRow: View {
    let carWash: CarWash

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.theme.surfaceHigh)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "car.top.radiowaves.rear.right")
                        .font(.system(size: 20))
                        .foregroundColor(.theme.textDisabled)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 10))
                    Text("세차장")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.pink)

                Text(carWash.name)
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                if !carWash.address.isEmpty {
                    Text(carWash.address)
                        .font(.appSmall)
                        .foregroundColor(.theme.textDisabled)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - 루틴 검색 결과 행
struct RoutineSearchRow: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.theme.surfaceHigh)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 20))
                        .foregroundColor(.theme.textDisabled)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 10))
                    Text("루틴")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.theme.primary)

                Text(routine.title)
                    .font(.appBodyMedium)
                    .foregroundColor(.theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let steps = routine.routineSteps {
                        Text("\(steps.count)단계")
                            .font(.appSmall)
                    }
                    Text(routine.durationText)
                        .font(.appSmall)
                }
                .foregroundColor(.theme.textDisabled)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.theme.textDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
