import SwiftUI
import WebKit

/// 약관/개인정보처리방침을 보여주는 WebView
struct LegalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Color.theme.surface)
        webView.scrollView.backgroundColor = UIColor(Color.theme.surface)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

/// 약관/개인정보 보기 전체 화면
struct LegalDocumentView: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.theme.textSecondary)
                    }
                    Spacer()
                    Text(title)
                        .font(.appBodyBold)
                        .foregroundColor(.theme.textPrimary)
                    Spacer()
                    // 균형을 위한 빈 공간
                    Color.clear.frame(width: 16, height: 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color.theme.border)

                LegalWebView(url: url)
            }
        }
    }
}
