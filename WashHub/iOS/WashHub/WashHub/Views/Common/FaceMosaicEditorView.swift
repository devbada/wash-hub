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
                    Text("모자이크 편집")
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

    /// 상단 안내 문구 — 모드별 + 자동 검출 0건일 때 별도 안내
    private var guidanceText: String {
        if isDrawMode {
            return "드래그하여 가릴 영역을 추가하세요"
        }
        if detectedFaces.isEmpty {
            return "가리고 싶은 영역이 있으면 '그리기'로 추가하세요"
        }
        return "탭하여 영역의 모자이크 적용을 선택/해제하세요"
    }

    // MARK: - 상단 바 (안내 + 모드 전환)
    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: isDrawMode ? "hand.draw.fill" : "hand.tap.fill")
                .font(.system(size: 14))
                .foregroundColor(isDrawMode ? .theme.tertiary : .theme.secondary)

            Text(guidanceText)
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
                        .fill((isDrawMode ? Color.theme.accent : Color.theme.accent).opacity(0.15))
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
            // scaledToFit 으로 인한 letterbox/pillarbox 영역을 계산.
            // 이미지가 실제로 표시되는 사각형(imageDisplayRect)을 기준으로 좌표 변환해야
            // 사용자가 드래그한 영역과 적용되는 모자이크 영역이 정확히 일치함.
            let imageDisplayRect = computeImageDisplayRect(
                imageSize: CGSize(width: imgW, height: imgH),
                containerSize: geo.size
            )
            let scaleX = imageDisplayRect.width / imgW
            let scaleY = imageDisplayRect.height / imgH

            ZStack(alignment: .topLeading) {
                // 기존 영역 박스 (자동 감지 + 수동) — imageDisplayRect.origin 으로 offset 보정
                ForEach(Array(detectedFaces.enumerated()), id: \.element.id) { index, face in
                    let rect = face.uiRect
                    let x = imageDisplayRect.origin.x + rect.origin.x * scaleX
                    let y = imageDisplayRect.origin.y + rect.origin.y * scaleY
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
                        .stroke(Color.theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.theme.accent.opacity(0.15))
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
                                    // 이미지 실제 표시 영역(imageDisplayRect) 내로 클램프 —
                                    // letterbox/pillarbox 영역에서 드래그 시작/끝 못 잡도록
                                    let clamped = CGPoint(
                                        x: min(max(value.location.x, imageDisplayRect.minX), imageDisplayRect.maxX),
                                        y: min(max(value.location.y, imageDisplayRect.minY), imageDisplayRect.maxY)
                                    )
                                    if dragStart == nil {
                                        dragStart = CGPoint(
                                            x: min(max(value.startLocation.x, imageDisplayRect.minX), imageDisplayRect.maxX),
                                            y: min(max(value.startLocation.y, imageDisplayRect.minY), imageDisplayRect.maxY)
                                        )
                                    }
                                    dragCurrent = clamped
                                }
                                .onEnded { _ in
                                    commitDragRegion(
                                        imageDisplayRect: imageDisplayRect,
                                        imageSize: CGSize(width: imgW, height: imgH)
                                    )
                                }
                        )
                }
            }
        }
    }

    /// scaledToFit 으로 표시될 때 이미지의 실제 표시 사각형 계산.
    /// 이미지 종횡비가 컨테이너보다 가로 우세면 위/아래에 letterbox,
    /// 세로 우세면 좌/우에 pillarbox 가 생김.
    private func computeImageDisplayRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        let imageRatio = imageSize.width / imageSize.height
        let containerRatio = containerSize.width / containerSize.height
        if imageRatio > containerRatio {
            // 가로 우세 → 컨테이너 가로 채움, 위/아래 letterbox
            let displayWidth = containerSize.width
            let displayHeight = displayWidth / imageRatio
            let originY = (containerSize.height - displayHeight) / 2
            return CGRect(x: 0, y: originY, width: displayWidth, height: displayHeight)
        } else {
            // 세로 우세 → 컨테이너 세로 채움, 좌/우 pillarbox
            let displayHeight = containerSize.height
            let displayWidth = displayHeight * imageRatio
            let originX = (containerSize.width - displayWidth) / 2
            return CGRect(x: originX, y: 0, width: displayWidth, height: displayHeight)
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
                        ? (face.isSelected ? Color.theme.accent : Color.white.opacity(0.6))
                        : (face.isSelected ? Color.theme.accent : Color.white.opacity(0.6)),
                    lineWidth: face.isSelected ? 3 : 2
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            face.isSelected
                                ? (face.isManual ? Color.theme.accent : Color.theme.accent).opacity(0.15)
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
                                        ? (face.isManual ? Color.theme.accent : Color.theme.accent)
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
        let faceCount = detectedFaces.filter { $0.kind == .face }.count
        let plateCount = detectedFaces.filter { $0.kind == .licensePlate }.count
        let manualCount = detectedFaces.filter { $0.kind == .manual }.count

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedCount)개 모자이크 적용")
                        .font(.appCaption)
                        .foregroundColor(.theme.textSecondary)
                    Text("얼굴 \(faceCount) · 번호판 \(plateCount) · 직접 \(manualCount)")
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

    /// 드래그 완료 → 수동 모자이크 영역 추가.
    /// 좌표 변환: 컨테이너 좌표 → imageDisplayRect 기준(letterbox 빼고) → 원본 이미지 좌표
    private func commitDragRegion(imageDisplayRect: CGRect, imageSize: CGSize) {
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

        // 표시 좌표 → 원본 이미지 좌표
        // 1) 컨테이너 기준 좌표에서 imageDisplayRect.origin 을 빼서 표시 영역 기준 좌표로
        // 2) 표시 영역 크기 → 원본 이미지 크기 비율로 변환
        let scaleX = imageSize.width / imageDisplayRect.width
        let scaleY = imageSize.height / imageDisplayRect.height

        let imgRect = CGRect(
            x: (displayRect.origin.x - imageDisplayRect.origin.x) * scaleX,
            y: (displayRect.origin.y - imageDisplayRect.origin.y) * scaleY,
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
