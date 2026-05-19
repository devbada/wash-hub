# WashHub — App Review Notes

> App Store Connect → **App Review Information → Notes** 섹션에 그대로 옮겨 적기 위한 문서.
> 심사관이 앱을 정확히 이해하고 효율적으로 테스트할 수 있도록 작성됨.
> **한국어 / English** 병기.

---

## 🇰🇷 한국어

### 1. 앱 개요 (한 줄 요약)

> WashHub는 한국 자동차 세차 애호가를 위한 모바일 소셜 커뮤니티입니다.
> 사용자가 세차 Before/After 사진을 공유하고, 케미컬·세차장 후기를 작성하며, 본인 세차 기록을 관리할 수 있습니다.

### 2. 핵심 기능

- **세차 피드** — Before/After 슬라이더 형태로 사진 비교 가능
- **케미컬 라이브러리** — 세차 용품 정보 + 별점 리뷰
- **세차장 정보** — 위치, 정보, 사용자 후기
- **내차 관리** — 보유 차량 + 세차 기록 (개인용)
- **세차 루틴** — 단계별 세차 가이드 작성·공유
- **세차 지수(Wash Index)** — 기상청 데이터로 오늘 세차 적합도 계산
- **세차 리듬** — 사용자별 다음 세차 추천일 표시

### 3. 앱 사용법 — 화면 구조와 기본 사용 흐름

#### 3-1. 탭 구조 (하단 5개)

```
[ 피드 ]  [ 케미컬 ]  [  +  ]  [ 세차장 ]  [ 내차 ]
   ↑         ↑         ↑          ↑          ↑
홈/타임라인  세차용품  글 작성    세차장 정보  내 차량
                       (FAB)                  /기록
```

마이페이지는 **피드 탭 우측 상단 프로필 아이콘**으로 진입.

#### 3-2. 각 탭의 핵심 화면

| 탭 | 핵심 화면 | 주요 동작 |
|---|---|---|
| **피드** | 메인 타임라인 (Wash Index 카드 + 피드 카드) | 좋아요, 댓글, 신고, 차단, Before/After 슬라이더 |
| **케미컬** | 세차 용품 라이브러리 (카드형) | 검색, 별점 리뷰 작성, 상세 페이지 |
| **+** (FAB) | 피드 작성 모달 | 사진 선택, 얼굴 모자이크, 차량 태그, 협찬 표시 |
| **세차장** | 지도 / 리스트 토글 | 위치 기반 검색, 후기 작성 |
| **내차** | 차량 + 세차 기록 + 통계 | 차량 등록, 세차 로그, 통계 차트, 세차 리듬 |

#### 3-3. 데모 데이터 (이미 준비됨)

심사관이 빈 화면을 보지 않도록 다음 시드 데이터가 미리 등록되어 있습니다:
- **WashHub 공식 계정** (officlal@washhub.app) — 운영자 컨텐츠
- **세차 루틴 10개** — "초보자 기본 손세차", "고광택 마무리", "겨울철 염화칼슘 제거" 등
- **케미컬 14개** — 카샴푸, 왁스, 코팅제, 휠클리너 등 카테고리별
- **세차장 정보** — 서울 일부 세차장 등록됨 (실제 데이터)

→ 신규 가입 직후 케미컬·세차장·루틴 탭에는 즉시 콘텐츠가 보입니다.

---

### 4. 시연 시나리오 (15분 안에 핵심 흐름 검토)

심사관이 다음 순서로 진행하시면 **모든 핵심 기능을 15분 안에 빠르게 확인** 가능합니다.

#### A. 첫 진입 — 회원가입 (3분)

1. 앱 실행 → 시작 화면에서 **"Sign in with Apple"** 선택
   - (Google 또는 게스트 모드 "먼저 둘러볼게요" 선택 가능)
2. Apple Sign-In 인증 완료
3. **이용약관 / 개인정보처리방침 동의** 화면
   - 두 약관 모두 "내용 보기" 로 열어 확인 가능 (in-app WebView, GitHub Pages 호스팅)
   - "[필수] 만 14세 이상" 체크 + 각 약관 동의
4. **닉네임 설정** — 2~10자 한글/영문 입력 (예: `리뷰어AppleTest`)
   - 욕설 / 관리자 사칭 키워드 자동 차단 (저장 시점에 검증)
5. 첫 진입 시 **온보딩 코치마크** 표시됨 (8단계)
   - 각 탭과 + 버튼 등 핵심 UI 설명
   - "건너뛰기" 또는 "다음" 버튼으로 진행
6. 메인 피드 진입 — 상단에 **Wash Index 카드** (서울 90점 등), 아래 피드 카드 표시

#### B. 콘텐츠 생성 — 피드 작성 (5분)

1. 하단 가운데 **녹색 + 버튼** 탭
2. 사진 선택 다이얼로그:
   - **Before** 사진 선택 (앨범 또는 카메라)
   - **After** 사진 선택
3. **얼굴 자동 모자이크 편집기** 자동 진입
   - 얼굴이 있으면 자동 감지 박스 표시 → 탭하여 적용/해제
   - "그리기" 모드 → 손가락 드래그로 임의 영역 추가
   - "모자이크 없이 사용" 도 가능
4. 본문 작성 + 차량 태그 (등록된 차량 있으면 선택) + 협찬 여부 토글
5. **게시하기** → 피드 목록 최상단에 새 피드 표시
6. 작성한 피드 탭 → 상세 화면에서 **Before/After 슬라이더** 좌우 드래그 — 비교 가능

#### C. 소셜 인터랙션 (3분)

1. 다른 사용자 피드 (또는 본인 피드) 에서:
   - **하트 ❤️** 탭하여 좋아요
   - **댓글** 작성
   - 우측 상단 **"..."** 메뉴 → 신고 / 사용자 차단
   - 신고 사유 선택 (스팸, 부적절, 저작권, 잘못된 정보 등)
   - 신고 완료 후 "이 사용자를 차단할까요?" alert 등장
2. 작성자 **아바타 탭** → UserProfileView 진입 → 팔로우 / 언팔로우
3. **피드 탭 우측 상단 아이콘들**:
   - 🔍 검색 (피드/케미컬/세차장/루틴 통합 검색)
   - 🔔 알림센터 (좋아요·댓글·팔로우 받은 이력)
   - 프로필 아이콘 → 마이페이지

#### D. 정보성 기능 — 케미컬 / 세차장 / 루틴 (2분)

1. **케미컬 탭** → 카드 리스트 → 상세
   - 별점 + 카테고리 + 사용 사례 + 사용자 리뷰
   - 본인 리뷰 작성 가능
2. **세차장 탭** → 우상단 토글로 지도/리스트 전환
   - 지도: 위치 권한 허용 시 현재 위치 + 주변 세차장 마커
   - 위치 거부해도 서울 기본 좌표로 동작 (제약 없음)
   - 상세 → 후기 작성 가능
3. **검색 탭** (피드 탭의 돋보기 아이콘) → "왁스" 등 검색 → 4개 카테고리 통합 결과

#### E. 내차 + 세차 통계 (2분)

1. **내차 탭** → "+ 차량 등록"
   - 차종 / 색상 / 연식 / 별칭 입력
2. 등록한 차량 카드 탭 → 차량 상세 + 세차 기록
3. 우상단 **세차 통계** 아이콘 → 월별 차트 + 자주 사용한 케미컬 TOP 5 + 자주 방문한 세차장 TOP 5
4. **세차 리듬** (피드 탭 마이페이지 또는 내차 탭) → "다음 세차 추천일" 표시

#### F. 약관 열람 + 회원탈퇴 (2분)

1. 마이페이지 → 설정 → **이용약관 / 개인정보처리방침** 탭
   - in-app WebView 로 외부 URL 로딩 (`https://devbada.github.io/wash-hub/`)
2. 마이페이지 하단 **회원탈퇴** → 확인 alert → 탈퇴 진행
3. 약 2~3초 후 로그인 화면으로 복귀
4. **동일 Apple ID 로 다시 로그인** 시도:
   - 같은 계정인데도 **신규 가입 흐름** (약관 동의 → 닉네임 설정) 으로 진입됨
   - 이전 user_id 와 별개의 새 회원으로 처리
   - 이전 작성 콘텐츠는 "[탈퇴한 사용자]" 표시로 보존됨 (피드 탭에서 확인 가능)
   - **이것이 본 앱의 핵심 차별 정책 — 9번 절 "탈퇴 정책" 참조**

---

### 4-1. 심사관이 꼭 해보길 권장하는 핵심 동작 (체크리스트)

심사관 입장에서 다음 8가지가 정상 동작하면 앱이 "출시 가능한 완성도" 라고 판단하실 수 있습니다.

- [ ] Sign in with Apple 로 신규 가입 → 약관 동의 → 닉네임 설정 → 메인 진입 (3분 이내)
- [ ] Before/After 피드 작성 → 얼굴 모자이크 편집 → 게시 → 슬라이더로 비교
- [ ] 좋아요 / 댓글 / 신고 (사유 선택) / 차단 동작
- [ ] 마이페이지 → 차량 등록 → 세차 통계 차트 표시
- [ ] 세차장 탭 → 지도/리스트 전환 → 위치 권한 거부해도 서울 기본 좌표로 정상 동작
- [ ] 케미컬·루틴 탭에서 시드 데이터 (운영자 게시물) 확인
- [ ] 마이페이지에서 약관 2종 모두 WebView 로 열림
- [ ] 회원탈퇴 → 동일 Apple ID 로 재가입 시 신규 회원으로 처리되는지 확인

### 5. 테스트 계정 (Apple Sign-In)

> Apple Sign-In 은 본인 Apple ID 로 가능하나, 별도 데모 계정 필요 시 다음을 참고하세요.

- **방법 A (권장):** 심사관 본인의 Apple ID 로 "Sign in with Apple" 진행 — 가입 즉시 신규 회원으로 처리되며, 테스트 후 마이페이지에서 즉시 탈퇴 가능합니다.
- **방법 B (데모 계정 요청 시):** 본 App Review Information 의 "Demo Account" 필드에 별도 제공된 Apple ID / 비밀번호 사용. (요청 받은 후 운영자가 회신)

> WashHub 는 자체 비밀번호 인증을 제공하지 않으며, **소셜 로그인 전용** 입니다.

### 6. 권한 사용 사유

| 권한 | 사용 시점 | 사유 |
|---|---|---|
| **카메라** | 피드 작성 시 사용자 선택 시에만 | 세차 Before/After 사진 즉시 촬영 |
| **사진 라이브러리** | 피드 작성 시 사용자 선택 시에만 | 앨범에서 세차 사진 선택 |
| **사진 라이브러리 (추가)** | 사용자가 명시적으로 저장 요청 시 | 완성된 비교 이미지 저장 |
| **위치 (사용 중에만)** | 세차장 탭 진입 시 또는 날씨 카드 갱신 시 | "주변 세차장 검색", "현재 위치 기반 날씨 정확도 향상". **원본 위·경도(latitude/longitude)는 서버로 전송·저장하지 않습니다.** 기기 내에서 5km × 5km 격자(기상청 nx/ny)로 변환되어 격자 좌표만 날씨 조회 요청에 사용됩니다. |

> 모든 권한은 **선택사항**입니다. 거부해도 서비스 핵심 기능 이용에 제약이 없습니다 (서울 기본 좌표로 fallback).

### 7. 콘텐츠 정책 (UGC Moderation)

- **NSFW 자동 차단** — 이미지 업로드 시 기기 내 Vision 프레임워크로 부적절 콘텐츠 자동 감지 후 차단
- **얼굴 모자이크** — 사진에 인물이 포함되면 얼굴 자동 감지 + 사용자가 모자이크 적용 가능 (기기 내 처리, 서버 전송 없음)
- **닉네임 욕설/관리자 사칭 필터** — 가입 및 닉네임 변경 시 한국어 욕설 사전(korcen) + 관리자 키워드(`administrator`, `관리자`, `운영자`, `admin` 등) 자동 차단
- **신고/차단 시스템** — 사용자가 부적절 콘텐츠 신고 가능. 신고 데이터는 운영자가 검토 후 처리
- **탈퇴자 익명화 보존** — 회원 탈퇴 시 식별 정보는 즉시 익명화, 콘텐츠는 "[탈퇴한 사용자]" 표시로 보존 (커뮤니티 정보 가치 유지)

### 8. 한국 법령 준수

WashHub 는 한국 시장 출시 앱이며 다음 법령을 준수합니다.

- 「개인정보 보호법」 제22조의2 (만 14세 미만 가입 금지), 제28조의8 (국외이전 고지), 제37조의2 (자동결정 이의제기), 제31조 (CPO 자연인 지정)
- 「정보통신망 이용촉진 및 정보보호 등에 관한 법률」 제22조의2 (앱 접근권한 고지), 제44조의7 (불법정보 유통금지), 제50조 (영리 광고)
- 「위치정보의 보호 및 이용 등에 관한 법률」 — 원본 좌표 비전송 정책으로 LBS 사업자 신고 면제
- 「공직선거법」 제250조·제251조·제82조의8 (딥페이크 선거 콘텐츠 금지) — 약관 명시
- 「표시·광고의 공정화에 관한 법률」 — 협찬 표시 의무 약관 명시

> 개인정보처리방침: https://devbada.github.io/wash-hub/privacy-policy.html
> 이용약관: https://devbada.github.io/wash-hub/terms-of-service.html

### 9. 탈퇴 정책 — 익명화 보존 방식

회원 탈퇴 시:
- **식별 정보** (이메일·프로필 사진·메타데이터·OAuth identity 매핑) → **즉시 익명화**
- **사용자 생성 콘텐츠** (피드·댓글·리뷰·루틴) → **작성자 표시만 "[탈퇴한 사용자]"** 로 변경 후 보존
- **신고/차단 이력** → SHA-256 가명화 보존 (1년 후 자동 파기)
- **재가입** → 동일 소셜 계정으로 가입 가능. 단 **별개의 새 회원**으로 처리되며 이전 콘텐츠는 복구되지 않음

심사관이 마이페이지 → 회원탈퇴 진행 후 다시 동일 Apple ID 로 로그인하시면 **새 회원으로 가입되는 흐름**을 확인하실 수 있습니다.

### 10. 알려진 한계 (Limitations)

| 항목 | 상태 | 비고 |
|---|---|---|
| 외부 푸시 알림 (FCM/APNs) | 미구현 | 좋아요·댓글 알림은 앱 내 알림센터에서만 표시 |
| 마케팅·광고성 정보 알림 | 미구현 | 약관·App Privacy 에 명시 |
| 만 14세 미만 사전 차단 | 약관 금지만 명시 | 소셜 계정 기본 정보로는 생년월일 미제공이라 사후 적발형 |
| 결제 / 인앱 구매 | 미구현 | 현재 전 기능 무료 |

### 11. 문의 채널

- 개인정보 보호책임자: **조홍래 (관리자)** — `xsitherx@gmail.com`
- App Review 관련 즉시 답변: 동일 이메일

---

## 🇺🇸 English

### 1. App Overview (One-liner)

> WashHub is a mobile social community for car wash enthusiasts in South Korea.
> Users share Before/After wash photos, write reviews of car wash chemicals and locations, and manage personal wash records.

### 2. Core Features

- **Wash Feed** — Before/After photo slider comparison
- **Chemical Library** — Car wash product info + star ratings
- **Car Wash Locations** — Map, info, and user reviews
- **My Car** — Personal vehicle + wash log management
- **Wash Routine** — Step-by-step shareable routines
- **Wash Index** — Daily wash suitability based on Korea Meteorological Administration data
- **Wash Rhythm** — Personalized next-wash recommendation

### 3. App Structure & Basic Usage

**Bottom tabs (5)**:
```
[ Feed ] [ Chemical ] [ + ] [ Car Wash ] [ My Car ]
```

My Page is accessed via the profile icon at the top-right of the Feed tab.

| Tab | Main Screen | Key Actions |
|---|---|---|
| Feed | Timeline + Wash Index card | Like, comment, report, block, Before/After slider |
| Chemical | Car-wash product library | Search, star ratings, write reviews |
| + (FAB) | Compose feed modal | Pick photos, face mosaic, tag car, sponsored toggle |
| Car Wash | Map / List toggle | Location-based search, write reviews |
| My Car | Vehicles + wash logs + stats | Register, log washes, statistics chart, Wash Rhythm |

**Seed data already populated** (reviewer won't see empty screens):
- WashHub official account with curated content
- 10 official wash routines
- 14 chemical products across categories
- A few car wash locations (Seoul)

### 4. Demo Walkthrough (15-min full flow)

**A. Sign Up (3 min)**
1. Launch → Login → **"Sign in with Apple"** or "Google"
2. **Terms of Service / Privacy Policy** consent screen — review both, agree
3. **Set Nickname** — 2-10 characters (e.g., `Reviewer`)
4. Confirm entry into main feed (Home tab)

**B. Create Content (5 min)**
1. Tap center **+** button in bottom tab → Create feed
2. Pick Before / After photos (album or camera)
3. **Face Mosaic Editor** — Auto-detect + manual drag-to-mask
4. Write body + tag car + toggle sponsored flag if applicable
5. Post → Verify the new post appears in the feed list

**C. Social Interaction (3 min)**
1. Tap heart (❤️) on a feed
2. Add a comment
3. Tap another user's avatar to open profile → Follow
4. Open "..." menu → Report/Block options (with reason selection)

**D. Account Management (2 min)**
1. My Page (top-right profile icon) → Verify "My Posts" and "Liked" tabs
2. Settings → Open Terms of Service / Privacy Policy (in-app WebView)
3. Withdraw → See anonymization in action (next section explains)

**E. Info Features (2 min)**
1. Chemicals tab → Search → Detail → Write review
2. Car Wash tab → Toggle Map / List → Detail
3. My Car tab → Register vehicle → Open Wash Statistics

### 4-1. Quick Verification Checklist (recommended for reviewers)

- [ ] Sign in with Apple → consent to ToS/Privacy → set nickname → enter main feed (<3 min)
- [ ] Create a Before/After feed → face mosaic editor → post → slide comparison
- [ ] Like / comment / report (with reason) / block
- [ ] My Page → register a car → open Wash Statistics chart
- [ ] Car Wash tab → toggle Map/List → verify default Seoul coordinates work even if location is denied
- [ ] See seed content in Chemical / Routine tabs
- [ ] Open both legal documents in WebView from My Page
- [ ] Withdraw → re-sign in with same Apple ID → confirm "new member" flow (previous content stays as "[Withdrawn User]")

### 5. Test Account

Sign in with the reviewer's own Apple ID is recommended — new accounts are created instantly upon first Sign in with Apple and can be withdrawn after testing.

Alternatively, if a demo account is required, please request via the email below and the operator will provision one. **No password-based login is supported** (social login only).

### 6. Permission Justifications

| Permission | When Requested | Reason |
|---|---|---|
| Camera | Only when user explicitly takes photos | Capture Before/After wash photos |
| Photo Library | Only when user picks photos | Select wash photos from album |
| Photo Library Add | Only when user saves output | Save merged comparison image |
| Location (When in Use) | Only when accessing car-wash map or weather card | "Find nearby car washes", "Local weather accuracy". **Raw lat/lng is NEVER sent to the server** — converted on-device to a 5km × 5km Korea Meteorological grid (nx/ny) before transmission. |

All permissions are **optional**. Denying any does not block core service usage (fallback to default Seoul coordinates).

### 7. Content Moderation

- **NSFW Auto-block** — On-device Vision framework analyzes uploads, blocks inappropriate content
- **Face Mosaic** — Auto-detect faces + user-controlled masking (on-device, no server transfer)
- **Nickname Filter** — Korean profanity dictionary (korcen) + admin-impersonation keywords blocked at registration
- **Report/Block System** — Users can flag inappropriate content; operator reviews
- **Anonymized Retention on Withdrawal** — On account deletion, identifying info is immediately anonymized; user-generated content is preserved with author shown as "[Withdrawn User]"

### 8. South Korean Regulatory Compliance

- Personal Information Protection Act — Articles 22-2 (under-14 ban), 28-8 (cross-border transfer disclosure), 31 (CPO designation), 37-2 (automated decision objection)
- Information and Communications Network Act — Articles 22-2 (permission disclosure), 44-7 (illegal info), 50 (commercial messaging)
- Location Information Protection Act — Raw coordinates never transmitted; LBS provider registration exempt
- Public Official Election Act — Articles 250/251/82-8 (deepfake election content prohibited) — disclosed in Terms

### 9. Withdrawal Policy (Anonymized Retention)

On account deletion:
- **Identifying info** (email, profile photo, metadata, OAuth identity mapping) → **immediately anonymized**
- **User-generated content** (feeds, comments, reviews, routines) → **author shown as "[Withdrawn User]"**, content preserved
- **Reports/Blocks history** → SHA-256 pseudonymized + auto-purged after 1 year
- **Re-registration** → Same social account can sign up again, but as a **brand new member**. Previous content is not restored.

### 10. Known Limitations

| Feature | Status | Note |
|---|---|---|
| External push notifications | Not implemented | In-app notification center only |
| Marketing notifications | Not implemented | Disclosed in Terms and App Privacy |
| Under-14 pre-check | Policy banned only | Disclosure-based, no birthdate validation (social accounts don't provide it) |
| Payments / IAP | Not implemented | All features currently free |

### 11. Contact

- Data Protection Officer: **Hongrae Cho (Administrator)** — `xsitherx@gmail.com`
- App Review questions: same email

---

## 📋 Submission Checklist (for the Operator)

App Store Connect 에 위 내용 입력 시:

- [ ] **App Review Information → Notes**: 위 한국어/영어 전체 또는 요약본 복붙
- [ ] **Sign-in Required**: ✅ Yes
- [ ] **Demo Account**:
  - User name: `(미리 준비한 Apple ID)` 또는 "Sign in with Apple — reviewer can use their own Apple ID"
  - Password: `(Apple ID 비밀번호)` 또는 "Not applicable — social login only"
- [ ] **Contact Information**: 조홍래 / xsitherx@gmail.com / +82-XX-XXXX-XXXX
- [ ] **Attachment** (선택): 본 문서 PDF 화하여 첨부
