import SwiftUI
import Supabase

struct CreateFeedView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var feedService = FeedService()
    @State private var title = ""
    @State private var content = ""
    @State private var location = ""
    @State private var washMethod = ""
    @State private var beforeImages: [UIImage] = []
    @State private var afterImages: [UIImage] = []
    @State private var extraImages: [UIImage] = []
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    // 내차 선택
    @State private var myCars: [MyCar] = []
    @State private var selectedCarId: String?

    // 이미지 피커 상태
    @State private var activePickerType: ImagePickerType?

    enum ImagePickerType: Identifiable {
        case before, after, extra
        var id: String { "\(self)" }
    }

    private var canSubmit: Bool {
        !title.isEmpty && !beforeImages.isEmpty && !afterImages.isEmpty && !isLoading
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.surface
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 제목
                        VStack(alignment: .leading, spacing: 8) {
                            Text("제목")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("세차 제목을 입력하세요", text: $title)
                                .washHubTextField()
                        }

                        // 내용
                        VStack(alignment: .leading, spacing: 8) {
                            Text("내용")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextEditor(text: $content)
                                .font(.appBody)
                                .foregroundColor(.theme.textPrimary)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color.theme.surface)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.theme.border, lineWidth: 1)
                                )
                                .onAppear {
                                    UITextView.appearance().backgroundColor = .clear
                                }
                        }

                        // 장소
                        VStack(alignment: .leading, spacing: 8) {
                            Text("세차 장소 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("장소를 입력하세요", text: $location)
                                .washHubTextField()
                        }

                        // 세차 방법
                        VStack(alignment: .leading, spacing: 8) {
                            Text("세차 방법 (선택)")
                                .font(.appLabel)
                                .foregroundColor(.theme.textSecondary)
                            TextField("예: 셀프 손세차, 자동세차 등", text: $washMethod)
                                .washHubTextField()
                        }

                        // 내차 선택
                        if !myCars.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("세차한 차량 (선택)")
                                    .font(.appLabel)
                                    .foregroundColor(.theme.textSecondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(myCars) { car in
                                            Button(action: {
                                                hideKeyboard()
                                                selectedCarId = selectedCarId == car.id ? nil : car.id
                                            }) {
                                                HStack(spacing: 8) {
                                                    if let imageUrl = car.imageUrl,
                                                       let url = URL(string: imageUrl) {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .success(let img):
                                                                img.resizable().scaledToFill()
                                                            default:
                                                                Image(systemName: "car.fill")
                                                                    .foregroundColor(.theme.textDisabled)
                                                            }
                                                        }
                                                        .frame(width: 32, height: 32)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    } else {
                                                        Image(systemName: "car.fill")
                                                            .font(.system(size: 16))
                                                            .foregroundColor(selectedCarId == car.id ? .white : .theme.textSecondary)
                                                    }

                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(car.carModel)
                                                            .font(.appSmall)
                                                            .foregroundColor(selectedCarId == car.id ? .white : .theme.textPrimary)
                                                        if let color = car.carColor {
                                                            Text(color)
                                                                .font(.system(size: 10))
                                                                .foregroundColor(selectedCarId == car.id ? .white.opacity(0.85) : .theme.textDisabled)
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    selectedCarId == car.id
                                                        ? Color.theme.secondary
                                                        : Color.theme.surface
                                                )
                                                .cornerRadius(10)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(
                                                            selectedCarId == car.id
                                                                ? Color.theme.secondary
                                                                : Color.theme.border,
                                                            lineWidth: 1
                                                        )
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Before / After 사진 (같은 행)
                        HStack(alignment: .top, spacing: 12) {
                            compactImageSection(
                                title: "Before",
                                images: $beforeImages,
                                maxCount: 5,
                                onAdd: { hideKeyboard(); activePickerType = .before }
                            )

                            compactImageSection(
                                title: "After",
                                images: $afterImages,
                                maxCount: 5,
                                onAdd: { hideKeyboard(); activePickerType = .after }
                            )
                        }

                        // 추가 사진 (선택)
                        wideImageSection(
                            title: "추가 사진 (선택)",
                            subtitle: "과정, 장비, 디테일 등",
                            images: $extraImages,
                            maxCount: 10,
                            onAdd: { hideKeyboard(); activePickerType = .extra }
                        )

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.appSmall)
                                .foregroundColor(.theme.error)
                        }

                        // 작성 완료 버튼 — Hero CTA
                        Button(action: submitFeed) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 132/255, green: 204/255, blue: 22/255),
                                                Color(red: 101/255, green: 163/255, blue: 13/255)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: Color(red: 101/255, green: 163/255, blue: 13/255).opacity(0.45), radius: 20, x: 0, y: 10)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("작성 완료")
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .ctaButtonStyle()
                            }
                        }
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1.0 : 0.45)
                        .scaleEffect(canSubmit ? 1.0 : 0.98)
                        .animation(.easeInOut(duration: 0.2), value: canSubmit)
                        .padding(.top, 4)
                    }
                    .padding(16)
                }
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationTitle("피드 작성")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundColor(.theme.textSecondary)
                }
            }
            .alert("작성 완료", isPresented: $showSuccess) {
                Button("확인") { dismiss() }
            } message: {
                Text("피드가 성공적으로 등록되었습니다!")
            }
            .task {
                await loadMyCars()
            }
            .sheet(item: $activePickerType) { type in
                ImagePicker { image in
                    switch type {
                    case .before:
                        if beforeImages.count < 5 { beforeImages.append(image) }
                    case .after:
                        if afterImages.count < 5 { afterImages.append(image) }
                    case .extra:
                        if extraImages.count < 10 { extraImages.append(image) }
                    }
                }
            }
        }
    }

    // MARK: - Before/After 컴팩트 이미지 섹션 (반반)
    private func compactImageSection(
        title: String,
        images: Binding<[UIImage]>,
        maxCount: Int,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.appLabel)
                    .foregroundColor(.theme.textSecondary)
                Spacer()
                Text("\(images.wrappedValue.count)/\(maxCount)")
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }

            // 이미지 그리드
            let cols = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(images.wrappedValue.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: images.wrappedValue[index])
                            .resizable()
                            .scaledToFill()
                            .frame(height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button(action: { images.wrappedValue.remove(at: index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .offset(x: 2, y: -2)
                    }
                }

                if images.wrappedValue.count < maxCount {
                    Button(action: onAdd) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.theme.surface)
                            .frame(height: 60)
                            .overlay(
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.theme.textDisabled)
                            )
                    }
                }
            }
        }
        .padding(12)
        .background(Color.theme.surface.opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.theme.border, lineWidth: 1)
        )
    }

    // MARK: - 추가 사진 와이드 섹션
    private func wideImageSection(
        title: String,
        subtitle: String,
        images: Binding<[UIImage]>,
        maxCount: Int,
        onAdd: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.appLabel)
                    .foregroundColor(.theme.textSecondary)
                Text(subtitle)
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
                Spacer()
                Text("\(images.wrappedValue.count)/\(maxCount)")
                    .font(.appSmall)
                    .foregroundColor(.theme.textDisabled)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(images.wrappedValue.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: images.wrappedValue[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button(action: { images.wrappedValue.remove(at: index) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .offset(x: 4, y: -4)
                        }
                    }

                    if images.wrappedValue.count < maxCount {
                        Button(action: onAdd) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.theme.surface)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 24))
                                        .foregroundColor(.theme.textDisabled)
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 내차 목록 로드
    private func loadMyCars() async {
        do {
            let session = try await supabase.auth.session
            let persistCars: [MyCar] = try await supabase
                .from("my_cars")
                .select()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("status", value: "ACTIVE")
                .order("is_primary", ascending: false)
                .execute()
                .value
            myCars = persistCars

            // 대표 차량 자동 선택
            if let primaryCar = persistCars.first(where: { $0.isPrimary }) {
                selectedCarId = primaryCar.id
            }
        } catch {
            print("MyCars load error: \(error)")
        }
    }

    // MARK: - 키보드 숨기기
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - 피드 제출
    private func submitFeed() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let beforeData = beforeImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
                let afterData = afterImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
                let extraData = extraImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

                _ = try await feedService.createFeed(
                    title: title.isEmpty ? nil : title,
                    content: content.isEmpty ? nil : content,
                    location: location.isEmpty ? nil : location,
                    washMethod: washMethod.isEmpty ? nil : washMethod,
                    carId: selectedCarId,
                    beforeImages: beforeData,
                    afterImages: afterData,
                    extraImages: extraData
                )

                NotificationCenter.default.post(name: .feedCreated, object: nil)
                showSuccess = true
            } catch {
                errorMessage = "피드 작성에 실패했습니다: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

// MARK: - UIKit ImagePicker (iOS 15 호환)
struct ImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
