# WashHub — App Store Connect App Privacy 라벨

> App Store Connect → 앱 → "App Privacy" 섹션 채울 때 그대로 옮겨 적기 위한 명세.
> 개인정보처리방침(`legal/privacy-policy.html`) 의 수집 항목과 1:1 매칭됨.
> 시행일: 2026-05-21

## 1. Data Used to Track You (추적 목적 수집)

| 항목 | 응답 |
|---|---|
| **데이터를 사용해 사용자를 추적합니까?** | **No** |

이유: 광고 식별자(IDFA) 수집·제3자 광고 네트워크 공유 없음. 분석은 자체 통계로만 활용.

---

## 2. Data Linked to You (식별자에 연결된 수집)

체크해야 할 카테고리:

### ✅ Contact Info
- [x] **Email Address** — Apple/Google 소셜 로그인 시 자동 제공
- Purposes: **App Functionality**, **Account Management**

### ✅ User Content
- [x] **Photos or Videos** — 피드 Before/After 이미지, 프로필 사진
- [x] **Other User Content** — 닉네임, 한줄소개, 피드 본문, 댓글, 리뷰, 루틴, 차량 정보, 세차 기록
- Purposes: **App Functionality**

### ✅ Identifiers
- [x] **User ID** — Supabase Auth user_id, Apple/Google provider sub
- Purposes: **App Functionality**, **Account Management**

### ✅ Usage Data
- [x] **Product Interaction** — 좋아요, 댓글, 팔로우, 검색 이력(최근 20건)
- Purposes: **App Functionality**, **Analytics**

### ✅ Diagnostics
- [x] **Crash Data** — Xcode/Apple 기본 충돌 보고 (Apple Privacy 정책에 따름)
- [x] **Performance Data** — 동일
- Purposes: **App Functionality**

### ❌ 수집 안 함
- Financial Info — 무상 SNS, 결제 정보 없음
- Health & Fitness — 없음
- Sensitive Info — 없음
- Contacts — 없음
- Search History (외부) — 앱 외부 검색 추적 없음
- Browsing History — 없음
- Location (정밀/대략) — 권한은 요청하나 **원본 좌표 서버 전송 없음** → 다음 절 참조
- Audio Data — 없음
- Other Data — 없음

---

## 3. Data Not Linked to You (식별자에 연결되지 않은 수집)

### ✅ Diagnostics
- [x] **Crash Data**, **Performance Data**, **Other Diagnostic Data**
- Purposes: **App Functionality**
- 비고: Xcode/Apple 기본 충돌 보고만 — 별도 분석 SDK(Firebase Crashlytics 등) 미사용

### ❌ Identifiers — Device ID (수집 안 함)
- **App Store Connect 답변: "No, this app does not collect Device IDs"**
- 사유: 앱 코드에서 `UIDevice.identifierForVendor`(IDFV) / IDFA / `systemVersion` / `model` 등을 직접 호출하지 않습니다. Supabase SDK 가 표준 HTTP 요청 시 자동 포함하는 User-Agent 정도는 일시적으로 인프라에 도달할 수 있으나 회사가 별도 보관·이용하지 않습니다.

### ⚠️ Location (특수 사례)
- **App Store Connect 답변: "No, this app does not collect Location"**
- 사유 명세 (심사관 질의 대비):
  > 위치 권한(`When in Use`)을 요청하나, 회사는 원본 위·경도(latitude/longitude)를 서버로 전송·저장하지 않습니다. 위·경도는 기기 내에서 약 5km × 5km 단위의 기상청 격자(nx/ny)로 변환되어 격자 좌표만 날씨 조회에 사용되고, 세차장 거리 계산은 모두 기기 내에서 수행됩니다. 따라서 「데이터 수집」 으로 분류하지 않습니다.

---

## 4. Tracking 동의 (ATT — App Tracking Transparency)

| 항목 | 응답 |
|---|---|
| **ATT 권한 요청합니까?** | **No** — 광고 추적 안 함, IDFA 미수집 |

---

## 5. 데이터 사용 목적 (Purposes) 분류 요약

| Purpose | 사용 데이터 |
|---|---|
| **App Functionality** | 모든 항목 (서비스 동작 자체) |
| **Account Management** | 이메일, User ID |
| **Analytics** | Usage Data (좋아요·댓글·검색 — 자체 통계만) |
| **Product Personalization** | ❌ (사용자별 추천 알고리즘 없음) |
| **Developer's Advertising or Marketing** | ❌ |
| **Third-Party Advertising** | ❌ |
| **Other Purposes** | ❌ |

---

## 6. 제3자 공유 (Third Parties)

| 제3자 | 공유 데이터 | 목적 |
|---|---|---|
| **Supabase Inc.** (미국) | 회원·콘텐츠·메타데이터 전반 | 데이터 호스팅, 인증, 파일 저장 (위탁) |
| **Apple Inc.** (미국) | OAuth 토큰 교환 시 이메일, 식별자 | Sign in with Apple |
| **Google LLC** (미국) | OAuth 토큰 교환 시 이메일, 식별자 | Google 계정 인증 |

> 광고 네트워크(AdMob 등), 분석 서비스(Firebase Analytics 등), CDN 등은 사용하지 않음.

---

## 7. 아동 (만 14세 미만) 데이터

| 항목 | 응답 |
|---|---|
| 아동 대상 서비스인가? | **No** |
| 아동 데이터 수집? | **No** — 약관상 만 14세 미만 가입 금지 (개인정보처리방침 제8조) |

---

## 8. 심사관 노트 (App Review Notes 에 첨부 권장)

```
WashHub 는 세차 커뮤니티 소셜 네트워킹 앱입니다.

[데이터 처리 정책 요약]
- 회원 식별자: Apple/Google OAuth 토큰 기반 (이메일 + provider sub)
- 콘텐츠 저장: Supabase (저장 리전 ap-northeast-2 서울)
- 위치 권한: 사용 중에만 허용. 원본 좌표 서버 전송 없음 — 기상청 5km 격자로 변환 후 격자만 전송
- 광고 추적: 없음 (ATT 미요청)
- 만 14세 미만: 가입 금지

[탈퇴 처리 — 익명화 보존]
회원 탈퇴 시 식별 정보(이메일·메타데이터·프로필 사진·닉네임)는 즉시 익명화되며,
작성 콘텐츠(피드·댓글·리뷰·루틴 등)는 "[탈퇴한 사용자]" 표시로 보존됩니다.
한국 「개인정보 보호법」 가명정보 처리(제2조 제1호의2) 원칙을 따릅니다.

[테스트 계정]
- 이메일: (App Store Connect → 심사 메모에 별도 제공)
- 비밀번호: 해당 없음 (소셜 로그인 전용)
```

---

## 9. 변경 이력

| 일자 | 변경 |
|---|---|
| 2026-05-14 | 최초 작성 — Reddit 익명화 보존 정책 + Apple Privacy 라벨 명세 |

## 10. ⚠️ 변호사 정식 검토 권고

위 명세는 자체 운영 정책 기반으로 작성됨. **App Store 심사 제출 전 변호사 검토 권장 사항:**
- Location 항목을 "Not Collected" 로 분류 가능한지 (격자 변환이라도 위치 정보 처리에 해당하는지)
- 한국 「개인정보 보호법」 가명정보 처리 명시와 Apple App Privacy 라벨의 정합성
- 만 14세 미만 차단 정책의 실효성 (생년월일 미검증)
