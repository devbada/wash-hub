# WashHub 테스트 전략

## 1. 현황 요약

WashHub는 iOS(Swift) + Supabase(Serverless) 아키텍처로, 현재 테스트 코드가 전혀 없는 상태입니다.

| 레이어 | 구성 요소 | 수량 |
|--------|-----------|------|
| iOS Services | AuthManager, FeedService 등 | 19개 |
| iOS Models | Profile, Feed, Comment 등 | 12개 |
| iOS Views | LoginView, FeedListView 등 | 22개+ |
| Supabase Edge Functions | withdraw-user, weather-proxy | 2개 |
| Supabase RLS Policies | profiles, feeds 등 전 테이블 | 다수 |
| DB Triggers | create_profile_on_signup 등 | 다수 |

## 2. 테스트 피라미드

WashHub의 Serverless 아키텍처에 맞춘 역삼각형 전략입니다. 별도 API 서버가 없으므로, **RLS 정책 테스트**와 **통합 테스트**가 가장 중요합니다.

```
      ╱ E2E (수동 QA) ╲           소수 — 실기기 테스트
     ╱  통합 테스트      ╲         핵심 — Supabase 연동
    ╱   단위 테스트        ╲       기반 — 모델, 로직 검증
   ╱  RLS / DB 테스트       ╲     필수 — 보안 경계 검증
```

## 3. 테스트 영역별 전략

### 3.1 RLS 정책 테스트 (최우선)

RLS가 유일한 접근 제어 수단이므로, 보안 테스트가 가장 중요합니다.

**테스트 방법:** Supabase SQL로 직접 검증

**대상 테이블 및 테스트 케이스:**

| 테이블 | 검증 항목 |
|--------|-----------|
| profiles | 본인만 UPDATE 가능, 타인 프로필 READ 가능, 타인 프로필 UPDATE 불가 |
| feeds | 본인 피드 CRUD 가능, 타인 피드 READ만 가능, 비로그인 시 READ만 가능 |
| feed_likes | 본인 좋아요 INSERT/DELETE 가능, 타인 좋아요 DELETE 불가 |
| comments | 본인 댓글 CRUD, 타인 댓글 READ만 가능 |
| my_cars | 본인 차량만 CRUD, 타인 차량 접근 불가 |
| wash_logs | 본인 세차 기록만 CRUD |
| reports | 본인 신고만 INSERT 가능, 타인 신고 조회 불가 |
| blocks | 본인 차단 INSERT/DELETE, 차단된 사용자 콘텐츠 필터링 |

**예시 테스트 SQL:**
```sql
-- 테스트: 타인의 프로필을 UPDATE 시도 (실패해야 함)
SET role authenticated;
SET request.jwt.claims = '{"sub": "user-a-uuid"}';

-- user-b의 프로필 수정 시도 → 0 rows affected 여야 정상
UPDATE profiles SET nickname = 'hacked' WHERE id = 'user-b-uuid';

-- 본인 프로필 수정 → 1 row affected 여야 정상
UPDATE profiles SET nickname = 'valid' WHERE id = 'user-a-uuid';
```

### 3.2 DB 트리거 테스트

| 트리거 | 검증 항목 |
|--------|-----------|
| create_profile_on_signup | 신규 가입 시 profiles 행 생성, 재가입 시 프로필 리셋(ON CONFLICT DO UPDATE) |
| update_updated_at_column | UPDATE 시 updated_at 자동 갱신 |
| 카운터 트리거 | 좋아요 추가/삭제 시 feed.like_count 증감, 댓글 추가/삭제 시 feed.comment_count 증감 |
| CASCADE 삭제 | auth.users 삭제 시 관련 데이터 전체 CASCADE 삭제 (car_washes, equipments 포함) |

### 3.3 Edge Function 테스트

**withdraw-user (v12)**

| 테스트 케이스 | 예상 결과 |
|--------------|-----------|
| 유효한 JWT로 탈퇴 요청 | 200, profiles/auth.users 삭제 |
| JWT 없이 요청 | 401 |
| 만료된 JWT로 요청 | 401 |
| Storage에 이미지가 있는 사용자 탈퇴 | 200, Storage 파일도 삭제 |
| deleteUser 실패 시 | 500 에러 반환 (200 반환 금지) |
| 탈퇴 후 동일 계정 재가입 | 새 프로필 생성, 약관 동의 필요 |

**weather-proxy**

| 테스트 케이스 | 예상 결과 |
|--------------|-----------|
| 유효한 좌표로 요청 | 200, 날씨 데이터 반환 |
| 잘못된 좌표 | 400 |
| 외부 API 타임아웃 | 적절한 에러 반환 |

### 3.4 iOS 단위 테스트 (XCTest)

**모델 테스트 (우선순위: 높음)**

| 모델 | 검증 항목 |
|------|-----------|
| Profile | CodingKeys 매핑 (snake_case → camelCase), displayName 기본값 "사용자" |
| Feed | JSON 디코딩, 옵셔널 필드 처리 |
| Comment | 중첩 구조 디코딩 |
| MyCar | 차량 정보 Codable 매핑 |

**서비스 로직 테스트 (우선순위: 높음)**

| 서비스 | 검증 항목 |
|--------|-----------|
| AuthManager | checkSession 상태 전환, loadProfile fallback 동작, needsTermsAgreement/needsNicknameSetup 플래그 로직 |
| AuthManager | prepareAppleSignIn nonce 생성, sha256 해시 정확성 |
| AuthManager | updateNickname 시 agreed_terms_at 포함 여부 |
| RoutineExecutionService | progress 계산, isCompleted 상태 판별, toggleStep 완료 자동 전환 |
| ReportService | 미인증 사용자 에러 처리 |

**예시 테스트 코드:**
```swift
import XCTest
@testable import WashHub

final class ProfileTests: XCTestCase {
    func test_displayName_nil이면_사용자_반환() {
        let profile = Profile(
            id: "test", username: nil, nickname: nil,
            avatarUrl: nil, bio: nil, carCount: nil,
            washCount: nil, followerCount: 0, followingCount: 0,
            isActive: true, titleBadgeId: nil, agreedTermsAt: nil,
            createdAt: nil, updatedAt: nil
        )
        XCTAssertEqual(profile.displayName, "사용자")
    }

    func test_displayName_닉네임_있으면_닉네임_반환() {
        let profile = Profile(
            id: "test", username: "email@test.com", nickname: "테스터",
            avatarUrl: nil, bio: nil, carCount: nil,
            washCount: nil, followerCount: 0, followingCount: 0,
            isActive: true, titleBadgeId: nil, agreedTermsAt: nil,
            createdAt: nil, updatedAt: nil
        )
        XCTAssertEqual(profile.displayName, "테스터")
    }

    func test_JSON_디코딩_snake_case_매핑() throws {
        let json = """
        {
            "id": "abc",
            "username": "test@email.com",
            "nickname": "닉네임",
            "avatar_url": "https://img.com/1.jpg",
            "follower_count": 10,
            "following_count": 5,
            "is_active": true,
            "agreed_terms_at": "2026-04-27T00:00:00Z"
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(Profile.self, from: json)
        XCTAssertEqual(profile.avatarUrl, "https://img.com/1.jpg")
        XCTAssertEqual(profile.followerCount, 10)
        XCTAssertEqual(profile.isActive, true)
        XCTAssertEqual(profile.agreedTermsAt, "2026-04-27T00:00:00Z")
    }
}
```

```swift
final class RoutineExecutionServiceTests: XCTestCase {
    func test_progress_빈_스텝_0반환() {
        let service = RoutineExecutionService()
        XCTAssertEqual(service.progress, 0)
    }

    func test_isCompleted_COMPLETED_상태() {
        let service = RoutineExecutionService()
        service.currentExecution = RoutineExecution(
            id: "1", routineId: "r1", userId: "u1",
            status: "COMPLETED", startedAt: "2026-01-01", completedAt: "2026-01-01"
        )
        XCTAssertTrue(service.isCompleted)
    }
}
```

### 3.5 iOS 통합 테스트

실제 Supabase 테스트 프로젝트 연동이 필요하며, Phase 5 이후 검토합니다.

| 플로우 | 검증 항목 |
|--------|-----------|
| 회원가입 | Apple 로그인 → 약관 동의 → 닉네임 설정 → 홈 진입 |
| 피드 CRUD | 작성 → 이미지 업로드 → 목록 노출 → 수정 → 삭제 |
| 좋아요/댓글 | 좋아요 → 카운트 증가 → 취소 → 카운트 감소 |
| 회원 탈퇴 | 탈퇴 → 데이터 삭제 → 재가입 → 새 프로필 |
| 내차/세차기록 | 차량 등록 → 세차 기록 → 장비 태그 |

### 3.6 E2E / 수동 QA 체크리스트

실기기 테스트로 수행하며, 기존 QA 체크리스트(26항목)를 활용합니다.

**Critical Path (반드시 통과):**
- 신규 가입 전체 플로우 (Apple → 약관 → 닉네임 → 홈)
- 피드 작성/수정/삭제
- 회원 탈퇴 → 재가입 (완전 초기화 확인)
- 게스트 모드 진입/제한
- 차단/신고 기능

## 4. 우선순위 로드맵

### Phase A: 즉시 (앱스토어 출시 전)
1. **수동 QA** — 26항목 체크리스트 전수 검사
2. **RLS 정책 SQL 테스트** — 보안 경계 검증 (SQL 스크립트)
3. **트리거 검증** — create_profile_on_signup, CASCADE 삭제

### Phase B: 출시 직후 (1~2주)
4. **iOS 모델 단위 테스트** — Profile, Feed, Comment Codable 검증
5. **iOS 서비스 로직 테스트** — AuthManager 플래그 로직, RoutineExecution 계산

### Phase C: 안정화 (1~2개월)
6. **Edge Function 테스트** — Deno test로 withdraw-user 검증
7. **iOS 통합 테스트** — Mock Supabase Client 활용

## 5. 테스트 커버리지 목표

| 영역 | Phase A | Phase B | Phase C |
|------|---------|---------|---------|
| RLS 정책 | 100% | 100% | 100% |
| DB 트리거 | 핵심 3개 | 전체 | 전체 |
| 모델 Codable | — | 80% | 90% |
| 서비스 로직 | — | 핵심 5개 | 전체 |
| Edge Function | 수동 | 수동 | 자동화 |
| E2E | 수동 26항목 | 수동 | 수동 |

## 6. 현재 발견된 테스트 갭 (Critical)

| 갭 | 위험도 | 설명 |
|----|--------|------|
| RLS 미검증 | 🔴 높음 | RLS가 유일한 보안 수단인데 자동화 테스트 없음 |
| 탈퇴 재가입 플로우 | 🔴 높음 | 트리거 실패 시 profiles 미생성, agreed_terms_at 유실 버그 발견 |
| 카운터 정합성 | 🟡 중간 | 좋아요/댓글 카운터 트리거의 동시성 검증 없음 |
| Edge Function 에러 핸들링 | 🟡 중간 | deleteUser 실패 시 500 반환 로직이 이전 버전에서 누락된 적 있음 |
| 이미지 모더레이션 | 🟢 낮음 | NSFWDetector 정확도 검증 없음 (Phase 4) |

## 7. 테스트 인프라 권장사항

### iOS (XCTest)
- Xcode 프로젝트에 WashHubTests 타겟 추가
- Supabase 의존성은 Protocol로 추상화 → Mock 주입
- CI: GitHub Actions + `xcodebuild test`

### Supabase RLS
- `supabase/tests/` 디렉토리에 SQL 테스트 파일 관리
- pgTAP 또는 수동 SQL 스크립트로 검증
- Supabase CLI: `supabase test db`

### Edge Functions
- Deno 내장 테스트 러너 사용
- `supabase/functions/withdraw-user/index.test.ts`
- `deno test` 또는 `supabase functions test`
