import SwiftUI

/// 얼굴 모자이크 편집 뷰
/// 감지된 얼굴을 오버레이로 표시하고, 탭하여 모자이크 선택/해제 가능
/// 드래그하여 수동 모자이크 영역 추가 가능
struct FaceMosaicEditorView: View {
    let originalImage: UIImage
    @Binding var detectedFaces: [DetectedFace]
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var previewImage: UIImage?

    // 드래그 상태
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var isDrawMode = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 안내 메시지 + 모드 전환
                    topBar

                    // 이미지 + 얼굴 오버레이
                    Image(uiImage: previewImage ?? originalImage)
                        .resizable()
                        .scaledToFit()
                        .overlay(faceOverlays)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(8)
                        .clipped()

                    // 하단 요약 + 버튼
                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("얼굴 모자이크")
                        .font(.appHeadline3)
                        .foregroundColor(.theme.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { onCancel() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
            .onAppear {
                updatePreview()
            }
        }
    }

    // MARK: - 상단 바 (안내 + 모드 전환)
    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: isDrawMode ? "hand.draw.fill" : "hand.tap.fill")
                .font(.system(size: 14))
                .foregroundColor(isDrawMode ? .theme.tertiary : .theme.secondary)

            Text(isDrawMode ? "드래그하여 모자이크 영역을 추가하세요" : "얼굴을 탭하여 모자이크를 선택/해제하세요")
                .font(.appCaption)
                .foregroundColor(.theme.textSecondary)
                .lineLimit(1)

            Spacer()

            // 모드 전환 버튼
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDrawMode.toggle()
                    // 모드 전환 시 드래그 상태 초기화
                    dragStart = nil
                    dragCurrent = nil
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isDrawMode ? "hand.tap" : "hand.draw")
                        .font(.system(size: 12, weight: .bold))
                    Text(isDrawMode ? "선택" : "그리기")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(isDrawMode ? .theme.secondary : .theme.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill((isDrawMode ? Color.theme.secondary : Color.theme.tertiary).opacity(0.15))
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.theme.surfaceLow)
    }

    // MARK: - 얼굴 오버레이 + 드래그 제스처
    private var faceOverlays: some View {
        GeometryReader { geo in
            let imgW = originalImage.size.width
            let imgH = originalImage.size.height
            let scaleX = geo.size.width / imgW
            let scaleY = geo.size.height / imgH

            ZStack(alignment: .topLeading) {
                // 기존 영역 박스 (자동 감지 + 수동)
                ForEach(Array(detectedFaces.enumerated()), id: \.element.id) { index, face in
                    let rect = face.uiRect
                    let x = rect.origin.x * scaleX
                    let y = rect.origin.y * scaleY
                    let w = rect.size.width * scaleX
                    let h = rect.size.height * scaleY

                    faceBox(index: index, face: face)
                        .frame(width: w, height: h)
                        .offset(x: x, y: y)
                }

                // 현재 드래그 중인 영역 표시
                if isDrawMode, let start = dragStart, let current = dragCurrent {
                    let dragRect = normalizedDragRect(start: start, current: current)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.theme.tertiary, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.theme.tertiary.opacity(0.15))
                        )
                        .frame(width: dragRect.width, height: dragRect.height)
                        .offset(x: dragRect.origin.x, y: dragRect.origin.y)
                }

                // 드래그 제스처 수신 레이어 (그리기 모드에서만)
                if isDrawMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    // 이미지 영역 내로 클램프
                                    let clamped = CGPoint(
                                        x: min(max(value.location.x, 0), geo.size.width),
                                        y: min(max(value.location.y, 0), geo.size.height)
                                    )
                                    if dragStart == nil {
                                        dragStart = CGPoint(
                                            x: min(max(value.startLocation.x, 0), geo.size.width),
                                            y: min(max(value.startLocation.y, 0), geo.size.height)
                                        )
                                    }
                                    dragCurrent = clamped
                                }
                                .onEnded { _ in
                                    commitDragRegion(
                                        containerSize: geo.size,
                                        imageSize: CGSize(width: imgW, height: imgH)
                                    )
                                }
                        )
                }
            }
        }
    }

    // MARK: - 개별 영역 박스
    private func faceBox(index: Int, face: DetectedFace) -> some View {
        ZStack {
            if !isDrawMode {
                // 선택 모드: 탭하여 토글
                Button(action: {
                    detectedFaces[index].isSelected.toggle()
                    updatePreview()
                }) {
                    boxContent(face: face)
                }
                .buttonStyle(.plain)
            } else {
                // 그리기 모드: 박스는 표시만 (탭 비활성)
                boxContent(face: face)
                    .opacity(0.6)
            }
        }
    }

    private func boxContent(face: DetectedFace) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    face.isManual
                        ? (face.isSelected ? Color.theme.tertiary : Color.white.opacity(0.6))
                        : (face.isSelected ? Color.theme.secondary : Color.white.opacity(0.6)),
                    lineWidth: face.isSelected ? 3 : 2
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            face.isSelected
                                ? (face.isManual ? Color.theme.tertiary : Color.theme.secondary).opacity(0.15)
                                : Color.clear
                        )
                )

            // 상태 아이콘 (우측 하단)
            VStack {
                // 수동 영역: 삭제 버튼 (좌측 상단)
                if face.isManual && !isDrawMode {
                    HStack {
                        deleteButton(face: face)
                        Spacer()
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: face.isSelected ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(
                                    face.isSelected
                                        ? (face.isManual ? Color.theme.tertiary : Color.theme.secondary)
                                        : Color.white.opacity(0.5)
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
            .padding(4)
        }
    }

    // MARK: - 수동 영역 삭제 버튼
    private func deleteButton(face: DetectedFace) -> some View {
        Button(action: {
            detectedFaces.removeAll { $0.id == face.id }
            updatePreview()
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
    }

    // MARK: - 하단 바
    private var bottomBar: some View {
        let selectedCount = detectedFaces.filter { $0.isSelected }.count
        let autoCount = detectedFaces.filter { !$0.isManual }.count
        let manualCount = detectedFaces.filter { $0.isManual }.count

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedCount)개 모자이크 적용")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                    Text("자동 \(autoCount)개 · 수동 \(manualCount)개")
                        .font(.system(size: 11))
                        .foregroundColor(.theme.textDisabled)
                }

                Spacer()

                Button(action: {
                    let allSelected = detectedFaces.allSatisfy { $0.isSelected }
                    for i in detectedFaces.indices {
                        detectedFaces[i].isSelected = !allSelected
                    }
                    updatePreview()
                }) {
                    Text(detectedFaces.allSatisfy({ $0.isSelected }) ? "전체 해제" : "전체 선택")
                        .font(.appCaptionMedium)
                        .foregroundColor(.theme.secondary)
                }
            }

            Button(action: {
                let finalImage = FaceMosaicService.shared.mosaicSelectedFaces(
                    in: originalImage, faces: detectedFaces
                )
                onConfirm(finalImage)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(selectedCount > 0 ? "모자이크 적용 (\(selectedCount)개)" : "모자이크 없이 사용")
                }
                .primaryButtonStyle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.theme.surfaceLow)
    }

    // MARK: - 드래그 영역 계산
    /// 드래그 시작/현재 좌표로 정규화된 사각형 (음수 방향 드래그 지원)
    private func normalizedDragRect(start: CGPoint, current: CGPoint) -> CGRect {
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// 드래그 완료 → 수동 모자이크 영역 추가
    private func commitDragRegion(containerSize: CGSize, imageSize: CGSize) {
        guard let start = dragStart, let current = dragCurrent else {
            dragStart = nil
            dragCurrent = nil
            return
        }

        let displayRect = normalizedDragRect(start: start, current: current)

        // 최소 크기 체크 (너무 작은 영역 무시)
        guard displayRect.width > 15 && displayRect.height > 15 else {
            dragStart = nil
            dragCurrent = nil
            return
        }

        // 화면 좌표 → 이미지 좌표
        let scaleX = imageSize.width / containerSize.width
        let scaleY = imageSize.height / containerSize.height

        let imgRect = CGRect(
            x: displayRect.origin.x * scaleX,
            y: displayRect.origin.y * scaleY,
            width: displayRect.width * scaleX,
            height: displayRect.height * scaleY
        )

        let manualFace = FaceMosaicService.shared.createManualRegion(
            uiRect: imgRect,
            imageSize: imageSize
        )

        detectedFaces.append(manualFace)
        updatePreview()

        dragStart = nil
        dragCurrent = nil
    }

    // MARK: - 미리보기 갱신
    private func updatePreview() {
        previewImage = FaceMosaicService.shared.mosaicSelectedFaces(
            in: originalImage, faces: detectedFaces
        )
    }
}
