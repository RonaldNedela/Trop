//
//  LoginWebView.swift
//  Trop
//
//  Created by 686udjie on 28/06/2026.
//

@preconcurrency import SwiftUI
import SwiftyTube
import UIKit
import WebKit

// Presented as a sheet — launches Google OAuth in a full-screen WKWebView, with manual cookie fallback
struct LoginWebView: View {
    let model: LoginViewModel
    @State private var showingManualInput = false
    @State private var cookieText = ""
    @State private var importError: String?
    @State private var isImporting = false

    var body: some View {
        Group {
            if showingManualInput {
                manualCookieView
            } else {
                Presenter(model: model)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle(showingManualInput ? "Import Cookies" : "Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(showingManualInput ? "Web Login" : "Paste Cookies") {
                    showingManualInput.toggle()
                }
            }
        }
    }

    private var manualCookieView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Import Session Cookies")
                    .font(.title2.bold())

                Text("If Google sign-in is blocked on your device or network, you can paste your cookies exported from any browser where you are logged into YouTube Music.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cookie String")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Paste from Clipboard") {
                            if let pasteboard = UIPasteboard.general.string {
                                cookieText = pasteboard
                            }
                        }
                        .font(.caption)
                    }

                    TextEditor(text: $cookieText)
                        .frame(minHeight: 120, maxHeight: 180)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.vertical, 4)
                }

                Button(action: importManualCookies) {
                    HStack {
                        Spacer()
                        if isImporting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(isImporting ? "Importing..." : "Import Cookies")
                            .bold()
                        Spacer()
                    }
                    .padding()
                    .background(cookieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(cookieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)

                VStack(alignment: .leading, spacing: 6) {
                    Text("How to get cookies:")
                        .font(.caption.bold())
                    Text("1. Open music.youtube.com in a browser and sign in.\n2. Export cookies (e.g. using a browser extension) in header format (name=value; name2=value2).\n3. Paste the string above and tap Import.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private func importManualCookies() {
        let trimmed = cookieText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isImporting = true
        importError = nil

        Task {
            do {
                try await AuthService.shared.importSession(from: trimmed)
                await model.restoreSessionIfPresent()
                await MainActor.run {
                    model.isPresented = false
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    importError = "Import failed: \(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }
}

// Bridges the WKWebView into SwiftUI using a hosting controller
private struct Presenter: UIViewControllerRepresentable {
    typealias UIViewControllerType = WebLoginController

    let model: LoginViewModel

    func makeUIViewController(context: UIViewControllerRepresentableContext<Presenter>) -> WebLoginController {
        WebLoginController(model: model)
    }

    func updateUIViewController(_ vc: WebLoginController, context: UIViewControllerRepresentableContext<Presenter>) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {}
}

// Controller that hosts a WKWebView for the Google OAuth flow
final class WebLoginController: UIViewController {
    let model: LoginViewModel
    private var delegate: LoginNavigationDelegate?

    init(model: LoginViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Formulates an authentic Mobile Safari user-agent string for the host device
    /// so Google's sign-in botguard security checks pass without flagging the embedded view.
    static var mobileSafariUserAgent: String {
        let osVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        let major = UIDevice.current.systemVersion.split(separator: ".").first ?? "15"
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(osVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(major).0 Mobile/15E148 Safari/604.1"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let delegate = LoginNavigationDelegate(model: model)
        self.delegate = delegate

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        // Start Google authentication with Mobile Safari UA to pass Google Botguard
        webView.customUserAgent = Self.mobileSafariUserAgent
        webView.navigationDelegate = delegate
        view = webView

        let url = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://music.youtube.com")!
        webView.load(URLRequest(url: url))
    }
}

// Handles navigation and extracts auth cookies on login redirect
private final class LoginNavigationDelegate: NSObject, WKNavigationDelegate {
    let model: LoginViewModel
    private var didCaptureSession = false

    init(model: LoginViewModel) {
        self.model = model
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
           let host = url.host?.lowercased(),
           host.contains("music.youtube.com") {
            // Once redirected to music.youtube.com, switch to Desktop UA for complete InnerTube cookie harvest
            if navigationAction.targetFrame?.isMainFrame == true {
                if webView.customUserAgent != LoginWebviewHarvest.userAgent {
                    Log.login.debug("Intercepted navigation to music.youtube.com — switching to desktop User-Agent")
                    webView.customUserAgent = LoginWebviewHarvest.userAgent
                    decisionHandler(.cancel)
                    var req = navigationAction.request
                    req.setValue(LoginWebviewHarvest.userAgent, forHTTPHeaderField: "User-Agent")
                    webView.load(req)
                    return
                }
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, url.host?.contains("music.youtube.com") == true else {
            return
        }
        guard !didCaptureSession, !model.isLoggedIn else { return }

        // Guarantee desktop UA on landing
        if webView.customUserAgent != LoginWebviewHarvest.userAgent {
            Log.login.debug("Landed on music.youtube.com with non-desktop UA — reloading with desktop UA")
            webView.customUserAgent = LoginWebviewHarvest.userAgent
            webView.reload()
            return
        }

        Log.login.debug("Redirected to \(url.host ?? "") — collecting cookies...")

        let dismissPromo = """
        (function() {
          var style = document.createElement('style');
          style.textContent = 'ytmusic-app-promo-renderer,#smart-banner,.smart-banner,\\
            [aria-label*="YouTube Music app"],tp-yt-paper-dialog[aria-label*="app"]{display:none!important}';
          document.head.appendChild(style);
          var dismiss = function() {
            var clickable = document.querySelectorAll('button,tp-yt-paper-button,yt-button-shape button,button[role="button"]');
            for (var i = 0; i < clickable.length; i++) {
              var t = (clickable[i].textContent || '').trim().toLowerCase();
              if (t === 'not now' || t === 'skip') { clickable[i].click(); break; }
            }
          };
          dismiss();
          setTimeout(dismiss, 1200);
        })();
        """
        webView.evaluateJavaScript(dismissPromo, completionHandler: nil)

        startHarvest(webView: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        Log.login.error("Login navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        Log.login.error("Login provisional navigation failed: \(error.localizedDescription)")
    }

    private func startHarvest(webView: WKWebView) {
        Task { @MainActor [weak self, weak webView] in
            guard let webView else { return }
            let session = await LoginWebviewHarvest.collectSession(from: webView) { [weak self] in
                guard let self, !self.didCaptureSession, !self.model.isLoggedIn else { return false }
                return true
            }
            guard let self, let (harvested, sapisid) = session else { return }
            self.importSession(harvested: harvested, sapisid: sapisid, webView: webView)
        }
    }

    private func importSession(harvested: [String: String], sapisid: String, webView: WKWebView) {
        didCaptureSession = true
        model.handleLogin(
            cookies: harvested,
            sapisid: sapisid,
            visitorData: harvested["visitor_data"],
            dataSyncId: model.dataSyncId
        )

        // Extract dataSyncId from the YouTube page config via JS injection
        webView.evaluateJavaScript("window.yt?.config_?.DATASYNC_ID ?? ''") { [weak self] result, error in
            if let dataSyncId = result as? String, !dataSyncId.isEmpty {
                self?.model.dataSyncId = dataSyncId
                Log.login.debug("  ✅ Found dataSyncId: \(dataSyncId.prefix(15))...")
            } else if let error {
                Log.login.error("  ⚠️ JS eval for dataSyncId failed: \(error.localizedDescription)")
            } else {
                Log.login.debug("  ⚠️ dataSyncId not found in page context")
            }
        }
    }
}
