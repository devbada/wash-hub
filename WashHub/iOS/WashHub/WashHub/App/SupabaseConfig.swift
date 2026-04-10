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
    // TODO-minam: 실제 Supabase 프로젝트 값으로 교체
    static let supabaseURL = "https://fwmttpobezntdxilntam.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3bXR0cG9iZXpudGR4aWxudGFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2MzExNTIsImV4cCI6MjA5MTIwNzE1Mn0.xSOG5t1oEryVenoMU1aDBClNG4nOThqXT5RqHvZ_fmM"

    // 구글 OAuth는 Supabase Dashboard에서 설정 (클라이언트 키 불필요)
    static let bundleID = "com.devbada.WashHub"
}
