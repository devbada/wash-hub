# WashHub — TestFlight & 심사 제출 절차

> Archive 빌드 → TestFlight 내부 테스트 → App Store 심사 제출까지의 단계별 가이드.

---

## 1. 사전 점검

### Xcode 설정
- [ ] Project → Signing & Capabilities — Team: `(개인 또는 회사 Team)`, Bundle ID: `com.devbada.WashHub`
- [ ] Build Configuration: **Release**
- [ ] Deployment Target: **iOS 15.0** (Profile 모델 호환성 기준)
- [ ] Version (CFBundleShortVersionString): `1.0.0`
- [ ] Build (CFBundleVersion): 매 업로드마다 +1 (예: `1`, `2`, `3`...)
- [ ] **Sign in with Apple** entitlement 활성

### Info.plist 확인 (project.pbxproj 의 INFOPLIST_KEY_*)
- [ ] `NSCameraUsageDescription` — "세차 사진을 촬영하기 위해 카메라 접근이 필요합니다"
- [ ] `NSPhotoLibraryUsageDescription` — "Before/After 사진을 선택하기 위해 사진 라이브러리 접근이 필요합니다"
- [ ] `NSPhotoLibraryAddUsageDescription` — "세차 사진을 저장하기 위해 사진 라이브러리 접근이 필요합니다"
- [ ] `NSLocationWhenInUseUsageDescription` — "주변 세차장을 찾고 정확한 날씨 정보를 제공하기 위해 위치 정보가 필요합니다."
- [ ] `CFBundleDisplayName` — "WashHub"

### Supabase 프로덕션 상태
- [ ] OAuth Providers 활성 (Apple + Google)
- [ ] Edge Functions 4개 ACTIVE (`withdraw-user` v23 / `weather-proxy` / `weather-history-collector` / `nickname-validate`)
- [ ] 모든 public 테이블 RLS ON
- [ ] pg_cron job 등록 (`cleanup_anonymized_reports_blocks_daily`)
- [ ] Storage 버킷 public 정책 (feeds, profiles, equipments, car-washes, my-cars)

### GitHub Pages
- [ ] `https://devbada.github.io/wash-hub/privacy-policy.html` 접근 OK
- [ ] `https://devbada.github.io/wash-hub/terms-of-service.html` 접근 OK
- [ ] 최신 시행일자 반영 확인 (2026-05-21)

---

## 2. Archive 빌드

### Step 1 — Clean
```
Xcode → Product → Clean Build Folder (⇧⌘K)
```

### Step 2 — Device 선택
Xcode 좌상단 타깃: **Any iOS Device (arm64)**

### Step 3 — Archive
```
Xcode → Product → Archive
```
약 3~5분 소요. 빌드 실패 시 에러 메시지 확인 후 수정.

### Step 4 — Organizer
Archive 완료 시 자동으로 Organizer 창 열림. 새 archive 선택 → **Distribute App**

### Step 5 — Distribution 선택
1. **App Store Connect** 선택
2. **Upload** 선택 (Export 가 아닌)
3. Distribution options: 모두 기본값
4. Re-sign: **Automatically manage signing**
5. **Upload** 클릭 → 약 5~10분 후 완료

### Step 6 — Upload 후 처리 대기
App Store Connect → My Apps → WashHub → TestFlight → Builds:
- 업로드 직후: "Processing" 상태 (10~30분)
- 처리 완료: "Ready to Submit" 또는 즉시 테스트 가능

---

## 3. TestFlight 내부 테스트

### 내부 테스터 추가
App Store Connect → TestFlight → **Internal Testing**:
1. **+ Add Internal Testers** — 본인 Apple ID, 동료 등 추가 (최대 100명)
2. 빌드 처리 완료 후 **Add Build** → 방금 업로드한 빌드 선택
3. 테스터에게 자동 초대 이메일 발송

### 테스터 측 (iPhone)
1. App Store 에서 **TestFlight** 앱 다운로드
2. 초대 이메일의 링크 → **Redeem** 또는 직접 TestFlight 앱에서 코드 입력
3. WashHub 베타 설치 → 테스트 시작
4. 피드백은 TestFlight 앱 내 "스크린샷 + 피드백" 기능 사용

### 검증 시나리오 (필수)
- [ ] 신규 가입 (Apple) → 약관 동의 → 닉네임 → 메인 진입
- [ ] 신규 가입 (Google) → 동일
- [ ] 피드 작성 → 사진 모자이크 편집 → 게시
- [ ] 댓글 / 좋아요 / 팔로우 / 신고 / 차단
- [ ] 마이페이지 → 프로필 수정 → 로그아웃 / 재로그인
- [ ] 회원 탈퇴 → 동일 Apple ID 로 다시 가입 → 새 회원 흐름 확인
- [ ] 코치마크 (첫 진입 시) 8단계 모두 진행
- [ ] 세차장 지도 → 권한 허용 / 거부 양쪽
- [ ] 케미컬 / 루틴 / 내차 / 세차 통계 진입
- [ ] iPad / 회전 (가로/세로) 동작 확인
- [ ] 다양한 네트워크 환경 (Wi-Fi / 셀룰러 / 약한 네트워크)

### 외부 테스터 (선택 — Beta App Review 필요)
출시 전 더 넓은 테스트가 필요하면 **External Testing** 그룹 추가. 최대 10,000명, 별도 Beta App Review (1~2일) 통과 필요.

---

## 4. App Store 심사 제출

내부 테스트 통과 후:

### Step 1 — App Information 입력
App Store Connect → My Apps → WashHub → **App Information**:
- [ ] **Bundle ID**: `com.devbada.WashHub`
- [ ] **Primary Category**: Social Networking
- [ ] **Privacy Policy URL**: `https://devbada.github.io/wash-hub/privacy-policy.html`
- [ ] **Marketing URL** (선택): 동일 또는 별도 랜딩 페이지
- [ ] **Subtitle** (30자 이내): "비가 와도 세차 — 세차 커뮤니티"

### Step 2 — Pricing and Availability
- [ ] 가격: **Free**
- [ ] Availability: **South Korea** (필요시 다른 국가 추가)

### Step 3 — App Privacy
**App Privacy** 섹션에 `docs/appstore-app-privacy.md` 내용 그대로 입력:
- [ ] Data Used to Track You: **No**
- [ ] Data Linked to You: Email, User Content, Identifiers, Usage Data, Diagnostics
- [ ] Data Not Linked to You: Diagnostics, Device ID
- [ ] Location: **Not Collected** (사유 메모 포함)

### Step 4 — Age Rating
설문 작성:
- 폭력성: None
- 성적 표현: None
- 도박: None
- 무서운 콘텐츠: None
- 의료 정보: None
- 사용자 생성 콘텐츠: **Yes — Infrequent/Mild** (UGC 가이드라인 + 신고/차단 명시)
- 결과: **4+** 또는 **9+** (UGC 때문에 9+ 가능)

### Step 5 — Version Information
- [ ] **Promotional Text** (170자 — 심사 없이 변경 가능): "비가 와도 세차! 세차 전후를 슬라이더로 비교하고, 케미컬·세차장을 진짜 후기로 골라보세요."
- [ ] **Description**: `docs/appstore-metadata.md` 의 한국어 본문 복붙
- [ ] **Keywords** (100자): `세차,세차장,디테일링,왁스,코팅,자동차,car wash,detailing,Before After,꿀팁`
- [ ] **What's New** (릴리스 노트): "WashHub 첫 출시 — 비가 와도 세차하는 분들을 위한 커뮤니티가 시작됩니다."
- [ ] **Support URL**: `mailto:xsitherx@gmail.com` 또는 GitHub Pages 지원 페이지
- [ ] **Screenshots**: `docs/screenshot-guide.md` 따라 준비한 8장 업로드

### Step 6 — Build 선택
TestFlight 에서 처리 완료된 빌드 선택 → "Add Build"

### Step 7 — App Review Information
- [ ] **Sign-in Required**: ✅ Yes
- [ ] **Demo Account**:
  - User name: 심사관 본인 Apple ID 사용 (Sign in with Apple) 또는 사전 준비된 데모 계정
  - Password: 해당 없음 (소셜 로그인 전용) 또는 데모 비밀번호
- [ ] **Contact Information**: 조홍래 / xsitherx@gmail.com
- [ ] **Notes**: `docs/app-review-notes.md` 내용 복붙 ⭐ **가장 중요**
- [ ] **Attachment** (선택): app-review-notes.md 를 PDF 화하여 첨부

### Step 8 — Version Release
- [ ] **Manually release this version** 선택 (심사 통과 후 본인이 출시 시점 결정)
- [ ] 또는 **Automatically release this version**

### Step 9 — Submit for Review
모든 섹션 ✅ 되면 우상단 **Submit for Review** 클릭. 심사 대기 1~3일 (평균).

---

## 5. 심사 결과 대응

### Approved ✅
- Manual release 면 우상단 **Release This Version** 클릭 → App Store 노출
- 약 30분~2시간 후 검색 가능

### Rejected ❌
- Reject 사유 확인 (Resolution Center)
- 해당 부분 수정 후 새 빌드 업로드 또는 답변 제출
- 흔한 reject 사유 + 답변 예시:
  - **2.1 App Completeness** — 데모 계정 명확하지 않음 → app-review-notes.md 의 데모 계정 섹션 재첨부
  - **5.1.1 Privacy Policy** — 약관 URL 작동 불가 → GitHub Pages 빌드 재확인
  - **4.0 Design** — UI 가 가이드라인 미흡 → 스크린샷·동작 영상 첨부 + 한국 세차 문화 컨텍스트 설명
  - **5.6 Developer Code of Conduct** — UGC 모더레이션 부족 → app-review-notes.md 의 "Content Moderation" 섹션 강조

---

## 6. 출시 후 관리

- [ ] App Store 노출 후 검색 키워드 모니터링 (`세차`, `세차장`, `car wash`)
- [ ] 사용자 리뷰 응답 (App Store Connect → Ratings and Reviews)
- [ ] Crash 모니터링 (Xcode → Window → Organizer → Crashes)
- [ ] 다음 버전 (1.0.1, 1.1) 로드맵 계획 — Phase 3 잔여 항목

---

## 7. 비상 연락처

- Apple Developer Program: [developer.apple.com/contact](https://developer.apple.com/contact/)
- App Review (영어): App Store Connect → Resolution Center
- Supabase 장애: [status.supabase.com](https://status.supabase.com)
- 본인 개인 비상: 조홍래 / xsitherx@gmail.com
