import Foundation
import Supabase

/// 닉네임 형식·금칙어 검증 공용 모듈.
///
/// 사용처:
/// - `NicknameSetupView` — 가입 후 최초 닉네임 설정
/// - `EditProfileView` — 마이페이지에서 닉네임 변경
///
/// 검증 순서:
/// 1. 길이 (min ~ max)
/// 2. 공백·이모지 등 잘못된 문자 (한글/영문/숫자/.-_ 만 허용)
/// 3. 욕설/비속어 사전
/// 4. 운영자 사칭 단어 (admin/washhub/관리자 등)
///
/// 모든 검증은 **정규화된 문자열** 기준 (소문자 + 공백/특수문자 제거) — 띄어쓰기·대소문자 우회 차단.
///
/// - Note: 한국어 욕설은 자모 분리(ㅅㅂ)·의도적 오타까지 100% 막기 어려움. 일반적인 패턴만
///   사전 차단하고, 잔여 케이스는 사용자 신고/관리자 차단으로 처리. (CONVENTIONS.md 9. 참조)
enum NicknameValidator {

    /// 검증 결과 — UI 가 분기해서 친화적 메시지로 변환
    enum ValidationError: Error, Equatable {
        case empty
        case tooShort(min: Int)
        case tooLong(max: Int)
        case invalidCharacter           // 허용 외 문자(이모지·특수문자 등)
        case containsForbiddenWord      // 욕설/비속어
        case containsReservedWord       // 운영자 사칭

        /// 사용자에게 보여줄 한국어 메시지
        var userMessage: String {
            switch self {
            case .empty:
                return "닉네임을 입력해주세요."
            case .tooShort(let min):
                return "닉네임은 \(min)자 이상이어야 합니다."
            case .tooLong(let max):
                return "닉네임은 \(max)자 이하여야 합니다."
            case .invalidCharacter:
                return "닉네임은 한글·영문·숫자만 사용할 수 있어요."
            case .containsForbiddenWord:
                return "사용할 수 없는 단어가 포함되어 있어요."
            case .containsReservedWord:
                return "운영자/공식 계정에서만 사용할 수 있는 단어입니다."
            }
        }
    }

    /// **실시간 입력용 검증** — 길이 + 문자만 확인.
    /// 사용자가 타이핑하는 동안 매 키 입력마다 호출되어도 부담 없음.
    /// 욕설/사칭 검증은 포함하지 않음 (저장 직전에만 검사).
    static func validateFormat(_ nickname: String, minLength: Int = 2, maxLength: Int = 20) throws -> String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 길이
        guard !trimmed.isEmpty else { throw ValidationError.empty }
        guard trimmed.count >= minLength else { throw ValidationError.tooShort(min: minLength) }
        guard trimmed.count <= maxLength else { throw ValidationError.tooLong(max: maxLength) }

        // 2. 문자 제한 — 한글(완성형 + 자모) / 영문 / 숫자 / 일부 구두점(_.-) 만 허용
        if trimmed.rangeOfCharacter(from: Self.allowedCharacterSet.inverted) != nil {
            throw ValidationError.invalidCharacter
        }

        return trimmed
    }

    /// **저장 직전 검증** — 형식(`validateFormat`) + 욕설 사전 + 운영자 사칭.
    /// 사용자가 "저장/완료" 버튼을 눌렀을 때 호출. 걸리면 throw.
    /// (원격 욕설 검증은 `validateProfanityRemote(_:)` — 이 메서드 통과 후 비동기로 별도 호출)
    static func validate(_ nickname: String, minLength: Int = 2, maxLength: Int = 20) throws -> String {
        // 1·2. 형식
        let trimmed = try validateFormat(nickname, minLength: minLength, maxLength: maxLength)

        // 3. 욕설/비속어 — 정규화된 문자열 기준
        let normalized = Self.normalize(trimmed)
        for word in Self.forbiddenWords {
            if normalized.contains(word) {
                throw ValidationError.containsForbiddenWord
            }
        }

        // 4. 운영자 사칭
        for word in Self.reservedWords {
            if normalized.contains(word) {
                throw ValidationError.containsReservedWord
            }
        }

        return trimmed
    }

    // MARK: - Internal

    /// 허용 문자: 한글(자모/완성형) + 영문 + 숫자 + `_`, `.`, `-`
    private static let allowedCharacterSet: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "_.-")
        set.formUnion(.alphanumerics)
        // 한글 완성형(가-힣) + 자모(ㄱ-ㅎ, ㅏ-ㅣ)
        set.insert(charactersIn: Unicode.Scalar(0xAC00)!...Unicode.Scalar(0xD7A3)!)
        set.insert(charactersIn: Unicode.Scalar(0x3131)!...Unicode.Scalar(0x318E)!)
        return set
    }()

    /// 정규화 — 소문자 + 공백/구두점 제거. 우회 차단용.
    static func normalize(_ s: String) -> String {
        return s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics
                .union(.init(charactersIn: "\u{AC00}"..."\u{D7A3}"))
                .union(.init(charactersIn: "\u{3131}"..."\u{318E}"))
                .inverted)
            .joined()
    }

    /// 욕설/비속어 사전 — 소문자 + 공백 없는 정규화 형태로 작성
    ///
    /// **운영 가이드**: 신고 누적 단어가 추가되면 이 배열에 한 줄씩 추가.
    /// 추가 시 false positive 방지를 위해 정상 닉네임 일부와 겹치지 않는지 확인 필수.
    private static let forbiddenWords: [String] = [
        // ─── 한국어 비속어 ───
        "씨발", "시발", "씨바", "씨불", "씨이발", "ㅅㅂ", "ㅆㅂ", "씨발놈", "씨발년", "시발놈", "시발년",
        "병신", "븅신", "ㅂㅅ", "병1신",
        "지랄", "ㅈㄹ", "지롤",
        "개새끼", "개새", "개쉑", "개색끼", "개색", "ㄱㅅㄲ", "ㄲㅅㄲ", "개세끼",
        "좆", "좃", "ㅈ같", "ㅈ까", "좆까", "좆같", "좆나",
        "씹", "씨박", "쉽창", "씹새", "씹창",
        "보지", "자지", "ㅈㅈ",
        "엿같", "엿먹",
        "꺼져", "닥쳐", "찌질",
        "미친놈", "미친년", "ㅁㅊ놈", "또라이", "또랑이",
        "후레자식", "후레", "호로",
        "썅", "쌍놈", "쌍년",
        // ─── 한국어 비속어 (강조/부사형) ── korcen 이 잡지 못하는 흔한 패턴 보강
        "존나", "졸라", "졸라리", "존맛", "존멋", "조낸", "존네", "졸ㄹㅏ",
        "빡친", "빡쳐", "빡침", "빡돌",
        "야이씨", "야씨",
        // ─── 영어 비속어 (정규화 후) ───
        "fuck", "fuk", "fck", "shit", "sh1t", "bitch", "btch",
        "asshole", "ahole", "cunt", "dick", "pussy", "pussi",
        "nigger", "nigga", "n1gga", "faggot", "fag", "retard", "retarded",
        "bastard", "motherfucker", "mthrfckr",
        // ─── 차별/혐오 표현 ───
        "장애새끼", "장애년", "장애놈",
        // ─── 커뮤니티 혐오어/비하 표현 ───
        "김치녀", "한남충", "한녀", "맘충", "급식충",
        "일베", "메갈", "워마드", "보슬"
    ]

    // MARK: - 원격 욕설 검증 (Edge Function: nickname-validate)
    //
    // 형식·길이·사칭 등 빠르게 판단 가능한 것은 위 `validate(_:minLength:maxLength:)` 가 즉시 처리.
    // 한국어 욕설은 자모 분리/우회 표기 등 복잡한 패턴이라 사전만으론 부족 → **korcen** (Apache 2.0)
    // 라이브러리를 Supabase Edge Function `nickname-validate` 로 self-host 해서 호출.
    //
    // 사용 패턴 (저장 직전 한 번만 호출 — 실시간 타이핑 X):
    // ```swift
    // let trimmed = try NicknameValidator.validate(input, minLength: 2, maxLength: 10)  // 즉시
    // try await NicknameValidator.validateProfanityRemote(trimmed)                     // 비동기
    // // 통과하면 저장 진행
    // ```
    //
    // 네트워크 실패 시: 보수적으로 통과 처리 (저장 자체는 막지 않음). 서버 측 추가 안전망(트리거)이
    // 들어가면 그쪽에서 한 번 더 검증. (현재는 클라이언트 검증만)

    /// Edge Function 응답 모델
    private struct RemoteValidateResponse: Decodable {
        let ok: Bool?
        let reason: String?
        let error: String?
    }

    /// 원격 욕설 검증 — 통과 시 그냥 리턴, 욕설 감지 시 `ValidationError.containsForbiddenWord` throw.
    /// 네트워크/서버 에러는 silent 통과 (UX 우선, 콘솔 로그만 남김).
    static func validateProfanityRemote(_ nickname: String) async throws {
        struct Payload: Encodable { let nickname: String }
        do {
            let response: RemoteValidateResponse = try await supabase.functions
                .invoke("nickname-validate", options: .init(body: Payload(nickname: nickname)))

            if response.ok == false {
                // korcen 이 욕설 감지한 케이스 — reason 은 현재 단일 값 ("profanity_detected")
                throw ValidationError.containsForbiddenWord
            }
            // ok=true 또는 error 필드만 있는 경우(잘못된 요청 등) — 통과
        } catch let err as ValidationError {
            throw err
        } catch {
            // 네트워크/디코딩 에러 — 보수적으로 통과 (저장은 막지 않음)
            print("⚠️ nickname-validate remote check failed (passing through): \(error)")
        }
    }

    /// 운영자/공식 계정·시스템 관리자 사칭 차단 — 일반 사용자가 사용 불가
    ///
    /// 정규화된 형태(소문자 + 공백·구두점 제거) 로 부분 매칭하므로
    /// "운 영 자", "ad-min", "관리.자" 같은 우회 표기도 자동 차단됨.
    private static let reservedWords: [String] = [
        // ─── 시스템/관리 권한 사칭 ───
        "admin", "administrator", "어드민", "어드미니스트레이터",
        "root", "superuser", "슈퍼유저",
        "system", "시스템", "sysadmin", "syadmin",
        "moderator", "moderate", "mod", "모더레이터", "모더",
        "manager", "매니저",
        "master", "마스터",
        "superadmin", "슈퍼관리자",

        // ─── 운영/조직 명칭 ───
        "관리자", "관리팀", "관리부",
        "운영자", "운영진", "운영팀", "운영부",
        "검열관", "심의위원",
        "ceo", "대표", "대표자", "본사", "headquarter",

        // ─── 서비스/브랜드 사칭 ───
        "washhub", "워시허브", "wash_hub", "wash-hub", "washhubofficial",
        "official", "공식", "공식계정", "verified", "인증", "인증된", "certified", "certifiedaccount",

        // ─── 고객지원 사칭 ───
        "support", "고객센터", "고객지원", "helpdesk", "help_desk", "helper",
        "service", "서비스센터", "cs", "csteam",

        // ─── 알림/공지 사칭 (시스템 메시지 위장) ───
        "notice", "공지", "공지사항", "알림", "notification",
        "announcement", "공지방", "공지봇",

        // ─── 봇/자동화 사칭 ───
        "bot", "봇", "chatbot", "챗봇", "autobot",

        // ─── 신고/제재 사칭 ───
        "report", "신고", "신고센터", "ban", "차단", "block",

        // ─── 직원 사칭 ───
        "staff", "직원", "임원", "팀장",
        "developer", "개발자", "engineer"
    ]
}
