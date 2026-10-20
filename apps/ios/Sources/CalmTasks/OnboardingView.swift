import SwiftUI
import CalmCore

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    private enum Step { case server, email, code }

    @State private var step: Step = .server
    @State private var server = ""
    @State private var email = ""
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 40)
                Text("Calm Tasks")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Calm.ink)
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(Calm.muted)

                switch step {
                case .server:
                    field("Indirizzo del server", text: $server, keyboard: .URL, placeholder: "nome-mac.tailnet.ts.net")
                    Text("Serve Tailscale attivo sull'iPhone e sul Mac.")
                        .font(.footnote).foregroundStyle(Calm.muted)
                case .email:
                    field("Email", text: $email, keyboard: .emailAddress, placeholder: "tu@esempio.it")
                case .code:
                    field("Codice", text: $code, keyboard: .numberPad, placeholder: "123456")
                    Text("Il server di casa non manda email. Il codice compare nel suo log.")
                        .font(.footnote).foregroundStyle(Calm.muted)
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(Calm.red)
                }

                Button(action: advance) {
                    HStack {
                        if busy { ProgressView().tint(.white) }
                        Text(buttonTitle).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy || !canAdvance)

                if step != .server {
                    Button("Indietro") { step = .server; error = nil }
                        .foregroundStyle(Calm.muted)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Calm.warm.ignoresSafeArea())
        .onAppear { if server.isEmpty { server = model.savedServer } }
    }

    private var subtitle: String {
        switch step {
        case .server: return "Collegati al tuo server Multica."
        case .email: return "Con quale email accedi?"
        case .code: return "Scrivi il codice di accesso."
        }
    }

    private var buttonTitle: String {
        switch step {
        case .server: return "Continua"
        case .email: return "Invia il codice"
        case .code: return "Entra"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .server: return !server.trimmingCharacters(in: .whitespaces).isEmpty
        case .email: return email.contains("@")
        case .code: return code.trimmingCharacters(in: .whitespaces).count >= 4
        }
    }

    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.weight(.medium)).foregroundStyle(Calm.soft)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Calm.line))
        }
    }

    private func advance() {
        error = nil
        busy = true
        Task {
            defer { busy = false }
            do {
                switch step {
                case .server:
                    try model.prepare(server: server)
                    step = .email
                case .email:
                    try await model.sendCode(email: email)
                    step = .code
                case .code:
                    try await model.verify(email: email, code: code)
                }
            } catch let failure as ServerConfigError {
                error = failure == .insecure ? "Serve un indirizzo https." : "Indirizzo non valido."
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
