import Foundation
import Supabase

/// Supabase 클라이언트 싱글턴
/// - Important: Anon Key만 클라이언트에 포함. Service Role Key는 절대 포함 금지.
let supabase = SupabaseClient(
    supabaseURL: URL(string: AppConfig.supabaseURL)!,
    supabaseKey: AppConfig.supabaseAnonKey
)

/// 앱 설정값 (빌드 환경별 분리 가능)
enum AppConfig {
    // 새 프로젝트 (region: ap-northeast-2, ref: mdqgipggvvksyvmziotq) — 2026-05-13 region 변경
    static let supabaseURL = "https://mdqgipggvvksyvmziotq.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kcWdpcGdndnZrc3l2bXppb3RxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1NTg3NzMsImV4cCI6MjA5NDEzNDc3M30.kWSaARhb_CzGdJKsxJ8E71bjJVF-xnsU3lRZTfJw9B8"

    // 구글 OAuth는 Supabase Dashboard에서 설정 (클라이언트 키 불필요)
    static let bundleID = "com.devbada.WashHub"
}
