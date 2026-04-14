# WashHub App Store 출시 체크리스트

> Supabase Serverless 아키텍처 기준 | 최종 수정: 2026-04-14

---

## 1. Apple Developer 계정 & 인증서

- [ ] Apple Developer Program 가입 완료 (연간 $99)
- [ ] Team ID: W96LW7FRSD 확인
- [ ] App Store 배포 인증서 (Distribution Certificate) 생성
- [ ] App Store 프로비저닝 프로파일 생성
- [ ] Sign in with Apple → Identifiers에서 App ID에 활성화 확인
- [ ] Push Notification 인증서 또는 Key (APNs) 설정 (푸시 알림용)

## 2. Xcode 빌드 설정

- [x] Bundle ID: `com.devbada.WashHub`
- [x] Display Name: `WashHub`
- [x] 카테고리: `public.app-category.social-networking`
- [x] MARKETING_VERSION: `1.0` (첫 출시)
- [x] CURRENT_PROJECT_VERSION: `1`
- [x] Deployment Target: iOS 15.0+ 확인
- [x] Entitlements: Sign in with Apple 활성화
- [x] Privacy 설명 (카메라, 사진 라이브러리, 위치)
- [x] 앱 아이콘 (1024x1024 포함) — Assets.xcassets에 등록
- [x] 라이트/다크/틴트 모드 앱 아이콘 3종 (iOS 18+)
- [ ] Release 빌드로 Archive 테스트

## 3. Supabase 프로덕션 설정

### 인증
- [ ] Apple OAuth: Supabase Dashboard → Auth → Apple 설정 확인
- [ ] Google OAuth: Supabase Dashboard → Auth → Google 설정 확인
- [ ] Redirect URL이 Info.plist URL Scheme과 일치 확인
  - URL Scheme: `com.washhub.ios` (Info.plist)
  - 또는 `com.devbada.WashHub` (SupabaseConfig.bundleID)
  - ⚠️ **둘 중 실제로 사용하는 것으로 통일 필요**
- [ ] JWT expiry, 세션 설정 확인

### 데이터베이스
- [ ] 모든 public 테이블에 RLS 활성화 확인
- [ ] RLS 정책 누락 없는지 점검
- [ ] 인덱스 최적화 확인 (피드 정렬, 검색 GIN 인덱스 등)
- [ ] profiles 트리거 (auth.users → profiles 자동 생성) 동작 확인
- [ ] 카운터 트리거 (like_count, comment_count 자동 증감) 확인

### Storage
- [x] `legal` 버킷 생성 (공개)
- [ ] `legal` 버킷에 `privacy-policy.html` 업로드
- [ ] `legal` 버킷에 `terms-of-service.html` 업로드
- [ ] `feeds` 버킷 존재 및 RLS 확인
- [ ] `profiles` 버킷 존재 및 RLS 확인
- [ ] Storage 파일 크기 제한 설정 확인

### Edge Functions
- [ ] `withdraw-user` 함수 배포 확인
- [ ] Edge Function Secrets 설정 확인

### 모니터링
- [ ] Supabase Dashboard → Logs 접근 확인
- [ ] Database 백업 설정 확인 (Supabase Pro 이상)

## 4. 약관 & 개인정보

- [x] 개인정보처리방침 HTML 작성 (`legal/privacy-policy.html`)
- [x] 이용약관 HTML 작성 (`legal/terms-of-service.html`)
- [x] 회원가입 시 약관 동의 화면 구현 (TermsAgreementView)
- [x] 마이페이지에서 약관/개인정보 열람 가능
- [x] profiles 테이블에 agreed_terms_at 컬럼 추가
- [ ] HTML 파일 Supabase Storage 업로드 후 URL 동작 확인

## 5. App Store Connect 설정

### 앱 정보
- [ ] App Store Connect에서 앱 생성
- [ ] 앱 이름: WashHub
- [ ] 부제목: 똑똑한 세차 관리
- [ ] 카테고리: 소셜 네트워킹
- [ ] 보조 카테고리: 라이프스타일

### 메타데이터
- [x] 한국어 설명 작성 (`docs/appstore-metadata.md`)
- [x] 영어 설명 작성 (`docs/appstore-metadata.md`)
- [x] 키워드 (한국어/영어) 작성
- [x] 프로모션 텍스트 작성
- [ ] 스크린샷 촬영 (6.7" iPhone 15 Pro Max 필수, 6.5" 선택)
  - 최소 3장, 최대 10장
  - 권장: 로그인, 피드 목록, 피드 상세, 케미컬 리뷰, 세차장, 루틴
- [ ] 앱 프리뷰 동영상 (선택, 15~30초)

### 심사 정보
- [ ] 개인정보 처리방침 URL 등록
- [ ] 연락처 정보 입력
- [ ] 심사 참고사항 입력 (소셜 로그인 안내, 게스트 모드 안내)
- [ ] 데모 계정 제공 방안 결정 (Apple/Google 로그인이라 별도 계정 불필요할 수 있음)

### 개인정보 보호 (App Privacy)
- [ ] 수집 데이터 유형 입력:
  - 연락처 정보 (이메일) — 계정 관리
  - 사용자 콘텐츠 (사진, 게시물) — 앱 기능
  - 식별자 (사용자 ID) — 계정 관리
  - 사용 데이터 — 분석
- [ ] "데이터 추적 안 함" 확인

### 연령 등급
- [ ] 콘텐츠 등급 질문지 작성
- [ ] UGC 포함 → "무제한 웹 액세스" 체크
- [ ] 예상 등급: 4+ 또는 12+ (UGC 포함 시)

## 6. 테스트

### 기능 테스트
- [ ] 신규 회원가입 플로우: Apple 로그인 → 약관 동의 → 닉네임 설정 → 메인
- [ ] 신규 회원가입 플로우: Google 로그인 → 약관 동의 → 닉네임 설정 → 메인
- [ ] 기존 회원 로그인 (약관 미동의 → 약관 동의 화면 표시)
- [ ] 기존 회원 로그인 (약관 동의 완료 → 바로 메인)
- [ ] 게스트 모드 진입 및 제한 기능 확인
- [ ] 피드 CRUD (작성, 수정, 삭제)
- [ ] 이미지 업로드 + 얼굴 모자이크
- [ ] 좋아요, 댓글, 신고, 차단
- [ ] 팔로우/언팔로우
- [ ] 케미컬/세차장 리뷰
- [ ] 통합 검색
- [ ] 프로필 수정
- [ ] 회원 탈퇴
- [ ] 푸시 알림 (설정된 경우)

### TestFlight
- [ ] Internal Testing 그룹 생성
- [ ] 첫 빌드 업로드 (Xcode → Archive → Upload to App Store Connect)
- [ ] TestFlight 빌드 승인 대기 (자동, 보통 수분~수시간)
- [ ] Internal Tester 초대 및 테스트
- [ ] 크래시 로그 확인
- [ ] External Testing (선택)

## 7. 최종 제출 전 확인

- [ ] Release 모드로 빌드 시 print 문 제거 또는 로그 레벨 확인
- [ ] 디버그 전용 코드 제거 확인
- [ ] API Key가 하드코딩된 곳 없는지 확인 (Supabase Anon Key는 공개 가능)
- [ ] 스크린샷이 실제 앱 화면과 일치하는지 확인
- [ ] 모든 메타데이터 오타 확인
- [ ] 개인정보 처리방침 URL 접근 가능 확인
- [ ] 이용약관 URL 접근 가능 확인

## 8. 제출 & 심사

- [ ] App Store Connect에서 "심사를 위해 제출"
- [ ] 심사 대기 (보통 24~48시간)
- [ ] 리젝 시 사유 확인 후 수정 재제출
- [ ] 승인 시 출시 방법 선택:
  - 즉시 출시
  - 특정 날짜에 출시
  - 수동 출시

---

## 자주 리젝되는 사유 & 대비

| 사유 | 대비 |
|------|------|
| 로그인 문제 | Apple 로그인 필수 (이미 구현), 게스트 모드 제공 |
| 개인정보 보호 | 개인정보처리방침 URL 제공, App Privacy 라벨 작성 |
| UGC 가이드라인 | 신고/차단 기능 구현 완료, 커뮤니티 가이드라인 약관에 명시 |
| 메타데이터 불일치 | 스크린샷과 실제 앱 일치 확인 |
| 미완성 기능 | 모든 탭의 기능이 동작하는지 확인 |
| 앱 크래시 | TestFlight에서 충분한 테스트 |
